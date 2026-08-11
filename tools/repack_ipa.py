#!/usr/bin/env python3
"""
Repack the CI-built jubeat plus .ipa with the game resources.

Fetches the latest CI-built .ipa (a freshly-built binary with none of the game resources, which are
not in the repo) through the GitHub REST API, extracts it, overlays the resources from the original
extracted ``Jubeat.app`` onto the fresh bundle's root, repacks the result into a new .ipa, signs it
with an Apple ID via ``plumesign`` (the only external process used), and optionally installs it to
the device.

The overlay mirrors the ``RESOURCES_DIR`` logic in the top-level ``CMakeLists.txt``: the game loads
its textures, plists, audio, and archives from the bundle root through
``[NSBundle.mainBundle pathForResource:]``, so the original app's resources are copied to the
``.app`` root, skipping the executable, code signature, provisioning profile, ``Info.plist``, and
``PkgInfo`` so the fresh build keeps its own.
"""
from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING, NoReturn
import argparse
import os
import shutil
import stat
import subprocess as sp
import sys
import tempfile
import zipfile

from tqdm import tqdm
import requests

if TYPE_CHECKING:
    from collections.abc import Sequence

__all__ = ('main',)

API = 'https://api.github.com'
_TIMEOUT = 60

# Bundle-native files the fresh build owns, so they are never overlaid from the original app. This
# mirrors the exclusion set in the top-level CMakeLists.txt RESOURCES_DIR block.
_BUILD_OWNED = frozenset({
    'Jubeat',
    '_CodeSignature',
    'CodeResources',
    'embedded.mobileprovision',
    'Info.plist',
    'PkgInfo',
})


def _die(message: str) -> NoReturn:
    """
    Print an error to stderr and exit with a non-zero status.

    Parameters
    ----------
    message : str
        The error message to print.
    """
    print(f'error: {message}', file=sys.stderr)
    raise SystemExit(1)


def _gh_token() -> str | None:
    """
    Read the github.com OAuth token from the gh CLI's ``~/.config/gh/hosts.yml``.

    Returns
    -------
    str | None
        The stored token, or ``None`` when the file or entry is absent.
    """
    hosts = Path.home() / '.config' / 'gh' / 'hosts.yml'
    if not hosts.is_file():
        return None
    host: str | None = None
    for line in hosts.read_text(encoding='utf-8').splitlines():
        if line[:1] and not line[:1].isspace():
            host = line.split(':', 1)[0].strip()
        elif host == 'github.com' and line.strip().startswith('oauth_token:'):
            return line.split(':', 1)[1].strip() or None
    return None


def _session(token: str | None) -> requests.Session:
    """
    Build a GitHub REST session, authenticated only when a token is given.

    The run and artifact listings work against the public API unauthenticated; a token is needed only
    when the artifact download is gated (a private repo, or GitHub declining an anonymous download).

    Parameters
    ----------
    token : str | None
        A GitHub token that can read the repo's Actions artifacts, or ``None`` for the public API.

    Returns
    -------
    requests.Session
        The configured session.
    """
    session = requests.Session()
    session.headers.update({
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
    })
    if token:
        session.headers['Authorization'] = f'Bearer {token}'
    return session


def _pick_run_id(session: requests.Session, repo: str, workflow: str, run_id: str | None) -> str:
    """
    Return the CI run id to pull, using @p run_id or the latest successful workflow run.

    Parameters
    ----------
    session : requests.Session
        The authenticated GitHub session.
    repo : str
        The ``owner/name`` repository.
    workflow : str
        The workflow file that builds the .ipa.
    run_id : str | None
        An explicit run id, or ``None`` to pick the latest successful run.

    Returns
    -------
    str
        The run id.
    """
    if run_id:
        return run_id
    response = session.get(f'{API}/repos/{repo}/actions/workflows/{workflow}/runs',
                           params={'status': 'success', 'per_page': 1},
                           timeout=_TIMEOUT)
    response.raise_for_status()
    runs = response.json().get('workflow_runs', [])
    if not runs:
        _die(f'No successful {workflow} runs were found for {repo}.')
    return str(runs[0]['id'])


def _download_artifact(session: requests.Session, repo: str, artifact: str, run_id: str,
                       destination: Path) -> None:
    """
    Download the named artifact archive for a run to a local zip file.

    Parameters
    ----------
    session : requests.Session
        The authenticated GitHub session.
    repo : str
        The ``owner/name`` repository.
    artifact : str
        The artifact name to download.
    run_id : str
        The run to download from.
    destination : Path
        The local path to write the artifact zip to.
    """
    response = session.get(f'{API}/repos/{repo}/actions/runs/{run_id}/artifacts', timeout=_TIMEOUT)
    response.raise_for_status()
    artifacts = [a for a in response.json().get('artifacts', []) if a['name'] == artifact]
    if not artifacts:
        _die(f'Artifact {artifact} was not found on run {run_id}.')
    with session.get(artifacts[0]['archive_download_url'], stream=True, timeout=_TIMEOUT) as archive:
        archive.raise_for_status()
        with destination.open('wb') as out:
            for chunk in archive.iter_content(chunk_size=1 << 16):
                out.write(chunk)


def _extract_zip(archive: Path, destination: Path) -> None:
    """
    Extract a zip, preserving unix permissions and symlinks.

    Parameters
    ----------
    archive : Path
        The zip file to extract.
    destination : Path
        The directory to extract into.
    """
    with zipfile.ZipFile(archive) as zip_file:
        for info in zip_file.infolist():
            target = destination / info.filename
            mode = info.external_attr >> 16
            if stat.S_ISLNK(mode):
                target.parent.mkdir(parents=True, exist_ok=True)
                if target.is_symlink() or target.exists():
                    target.unlink()
                target.symlink_to(zip_file.read(info).decode())
            elif info.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with zip_file.open(info) as source, target.open('wb') as out:
                    shutil.copyfileobj(source, out)
                if mode:
                    target.chmod(stat.S_IMODE(mode))


def _find_ipa(download_dir: Path) -> Path:
    """
    Locate the .ipa in the extracted artifact, unwrapping a nested .zip when needed.

    Parameters
    ----------
    download_dir : Path
        The directory the artifact was extracted into.

    Returns
    -------
    Path
        The located .ipa file.
    """

    def ipa_files(root: Path) -> list[Path]:
        return sorted(p for p in root.rglob('*') if p.is_file() and p.suffix.lower() == '.ipa')

    if found := ipa_files(download_dir):
        return found[0]
    zips = sorted(p for p in download_dir.rglob('*') if p.is_file() and p.suffix.lower() == '.zip')
    if not zips:
        _die('No .ipa or .zip was found in the artifact.')
    nested = download_dir / 'nested'
    _extract_zip(zips[0], nested)
    if found := ipa_files(nested):
        return found[0]
    _die('No .ipa was found after extracting the artifact.')


def _find_app(payload: Path) -> Path:
    """
    Find the ``.app`` bundle directly under a Payload directory.

    Parameters
    ----------
    payload : Path
        The ``Payload`` directory to search.

    Returns
    -------
    Path
        The ``.app`` bundle directory.
    """
    apps = sorted(p for p in payload.glob('*.app') if p.is_dir())
    if not apps:
        _die(f'No .app was found under {payload}.')
    return apps[0]


def _overlay_resources(resource_root: Path, app: Path) -> int:
    """
    Copy the original app's resources onto the fresh bundle's root.

    Every top-level entry is copied except the build-owned files (the executable, code signature,
    provisioning profile, ``Info.plist``, and ``PkgInfo``), matching the CMake ``RESOURCES_DIR``
    exclusion set so the fresh build keeps its own executable and metadata.

    Parameters
    ----------
    resource_root : Path
        The directory holding the original app's resources.
    app : Path
        The freshly-built ``.app`` bundle to overlay onto.

    Returns
    -------
    int
        The number of top-level entries copied.
    """
    copied = 0
    for entry in sorted(resource_root.iterdir()):
        if entry.name in _BUILD_OWNED:
            continue
        target = app / entry.name
        if entry.is_dir() and not entry.is_symlink():
            shutil.copytree(entry, target, symlinks=True, dirs_exist_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(entry, target, follow_symlinks=False)
        copied += 1
    return copied


def _make_ipa(payload_parent: Path, archive: Path) -> None:
    """
    Zip the bundle directory into an unsigned .ipa, preserving unix modes and symlinks.

    Parameters
    ----------
    payload_parent : Path
        The directory that contains the ``Payload`` directory to pack.
    archive : Path
        The output unsigned .ipa path.
    """
    base = payload_parent / 'Payload' if (payload_parent / 'Payload').is_dir() else payload_parent
    entries = sorted(base.rglob('*'))
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as zip_file:
        for path in tqdm(entries, desc='Packing the IPA', unit='file'):
            archived_name = str(path.relative_to(payload_parent))
            mode = path.lstat().st_mode
            if path.is_symlink():
                info = zipfile.ZipInfo(archived_name)
                info.external_attr = (mode & 0xFFFF) << 16
                zip_file.writestr(info, os.readlink(path))
            elif path.is_dir():
                info = zipfile.ZipInfo(archived_name + '/')
                info.external_attr = ((mode & 0xFFFF) << 16) | 0x10
                zip_file.writestr(info, b'')
            else:
                info = zipfile.ZipInfo(archived_name)
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = (mode & 0xFFFF) << 16
                zip_file.writestr(info, path.read_bytes())


def _resolve_plumesign(override: str | None) -> str:
    """
    Resolve the plumesign binary from the flag or the usual locations.

    Parameters
    ----------
    override : str | None
        An explicit plumesign path, or ``None`` to search ``PATH`` and the working directory.

    Returns
    -------
    str
        The resolved plumesign command or path.
    """
    if override:
        return override
    if found := shutil.which('plumesign-linux-x86_64'):
        return found
    local = Path.cwd() / 'plumesign-linux-x86_64'
    if os.access(local, os.X_OK):
        return str(local)
    _die('The plumesign-linux-x86_64 binary was not found; pass --plumesign or --skip-sign.')


def _parse_args(argv: Sequence[str] | None) -> argparse.Namespace:
    """
    Parse the command-line arguments.

    Parameters
    ----------
    argv : Sequence[str] | None
        The command-line arguments (defaults to ``sys.argv``).

    Returns
    -------
    argparse.Namespace
        The parsed arguments.
    """
    parser = argparse.ArgumentParser(description='Repack the CI-built .ipa with the game resources.')
    parser.add_argument('resources_dir',
                        type=Path,
                        help='the original extracted Jubeat.app (or a directory of its resources) '
                        'whose textures, plists, audio, and archives the code-only CI build lacks; '
                        'overlaid onto the fresh bundle root, read only')
    parser.add_argument('output_ipa',
                        nargs='?',
                        type=Path,
                        default=Path.cwd() / 'Jubeat-signed.ipa',
                        help='output path for the final .ipa (default: ./Jubeat-signed.ipa)')
    parser.add_argument('--token',
                        default=None,
                        help='GitHub token that can read the artifacts (default: the gh CLI token '
                        'from ~/.config/gh/hosts.yml, else the public API)')
    parser.add_argument('--repo', default='Tatsh/expert-satphone', help='the owner/name repo')
    parser.add_argument('--artifact', default='Jubeat-adhoc-ipa', help='the artifact name')
    parser.add_argument('--workflow', default='build.yml', help='the workflow that builds the .ipa')
    parser.add_argument('--run-id', default=None, help='a run id (default: latest successful run)')
    parser.add_argument('--plumesign', default=None, help='path to the plumesign binary')
    parser.add_argument('--plumesign-arg',
                        action='append',
                        default=[],
                        dest='plumesign_args',
                        metavar='ARG',
                        help='an extra argument appended to plumesign sign (repeatable)')
    parser.add_argument('--udid', default='1', help='device UDID to install to')
    parser.add_argument('--no-install', action='store_true', help='sign only; do not install')
    parser.add_argument('--skip-sign', action='store_true', help='emit the unsigned repacked .ipa')
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    """
    Run the repack pipeline.

    Parameters
    ----------
    argv : Sequence[str] | None
        The command-line arguments (defaults to ``sys.argv``).

    Returns
    -------
    int
        The process exit status.
    """
    args = _parse_args(argv)

    if not args.resources_dir.is_dir():
        _die(f'The resources directory does not exist: {args.resources_dir}')

    # Resolve the signer up front so we fail fast before downloading anything.
    plumesign = '' if args.skip_sign else _resolve_plumesign(args.plumesign)

    resource_root = args.resources_dir.resolve()
    output_ipa = args.output_ipa.resolve()

    session = _session(args.token or _gh_token())
    with tempfile.TemporaryDirectory() as work_name:
        work = Path(work_name)

        run_id = _pick_run_id(session, args.repo, args.workflow, args.run_id)
        print(f'Using run {run_id} of {args.repo}, artifact {args.artifact}.')

        download = work / 'dl'
        download.mkdir()
        artifact_zip = work / 'artifact.zip'
        _download_artifact(session, args.repo, args.artifact, run_id, artifact_zip)
        _extract_zip(artifact_zip, download)

        ipa = _find_ipa(download)
        print(f'Found the built IPA {ipa.name}.')

        extract = work / 'ipa'
        _extract_zip(ipa, extract)

        # The code-only CI build ships the executable, Info.plist, and signature but no resources.
        # Overlay the original app's resources onto the bundle root, matching CMake's RESOURCES_DIR.
        app = _find_app(extract / 'Payload')
        print(f'Overlaying resources onto {app.name}.')
        copied = _overlay_resources(resource_root, app)
        print(f'Copied {copied} top-level resource entries.')

        unsigned = work / 'unsigned.ipa'
        _make_ipa(extract, unsigned)

        output_ipa.unlink(missing_ok=True)
        if args.skip_sign:
            shutil.copyfile(unsigned, output_ipa)
            print(f'Wrote the unsigned IPA to {output_ipa}.')
        else:
            print(f'Signing with the Apple ID via {Path(plumesign).name}.')
            sp.run((plumesign, 'sign', '--package', str(unsigned), '--apple-id', '-o',
                    str(output_ipa), *args.plumesign_args),
                   check=True)
            print(f'Wrote the signed IPA to {output_ipa}.')

        # Install to the device, a separate step. Skipped when unsigned or when --no-install.
        if args.skip_sign or args.no_install:
            print('Skipping the device install.')
        else:
            print(f'Installing to device {args.udid}.')
            sp.run((plumesign, 'device', '--udid', args.udid, '--install', str(output_ipa)),
                   check=True)
            print('Installed to the device.')

    return 0


if __name__ == '__main__':
    raise SystemExit(main())
