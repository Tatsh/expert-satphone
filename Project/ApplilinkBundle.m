#import "ApplilinkBundle.h"

#import "ApplilinkCore.h"

// The name and type of the SDK's localised resource bundle inside the main bundle, from the
// CFStrings at 0x2e3bc0 and 0x2e3be0.
static NSString *const kResourceBundleName = @"ApplilinkNetworkResources";
static NSString *const kResourceBundleType = @"bundle";

// The format that builds the localised sub-bundle path, from the CFString at 0x2e3c00.
static NSString *const kLocalizedBundlePathFormat = @"%@/%@.lproj";

@implementation ApplilinkBundle

/** @ghidraAddress 0x2372f4 */
+ (NSBundle *)rewardBundle {
    // Storage at 0x354288 with the once token immediately after it at 0x354290.
    static NSBundle *bundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      /** @ghidraAddress 0x237338 */
      NSString *path = [NSBundle.mainBundle pathForResource:kResourceBundleName
                                                     ofType:kResourceBundleType];
      // Tests -length rather than nil, so an empty string bails out too.
      if (path.length == 0) {
          return;
      }
      if (ApplilinkCore.isPriorityDeviceLanguages) {
          NSString *language = [NSLocale.preferredLanguages objectAtIndex:0];
          NSString *localizedPath =
              [NSString stringWithFormat:kLocalizedBundlePathFormat, path, language];
          bundle = [NSBundle bundleWithPath:localizedPath];
      }
      // Reached either because the language branch was skipped or because it found nothing.
      if (bundle == nil) {
          bundle = [[NSBundle alloc] initWithPath:path];
      }
      // The same class in ../rbplus-src ends with an NSLog when the bundle is still nil here. This
      // build has no such call: the store at 0x2374e4 falls straight through to the epilogue.
    });
    return bundle;
}

@end
