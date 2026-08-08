//
//  main.m
//  jubeat plus
//
//  Application entry point. Reconstructed from Ghidra program Jubeat (entry @ 0x7b08, relative to
//  the image base 0x100000000). The binary's entry does exactly what a standard iOS main() emits:
//  push an autorelease pool, call UIApplicationMain, then pop the pool on the result's way out.
//  The objc_autoreleasePoolPush/Pop pair Ghidra shows is the @autoreleasepool lowering.
//
//  Argument order was read from the disassembly rather than the decompile: x0 and x1 are forwarded
//  unchanged from main's own argc and argv, x2 is set to 0 (a nil principalClassName), and x3
//  points at the embedded CFString at 0x2d40a0, whose data pointer 0x27dc10 holds the 17-character
//  string "JubeatAppDelegate". That is equivalent to NSStringFromClass([JubeatAppDelegate class]).
//

#import <UIKit/UIKit.h>

#import "JubeatAppDelegate.h"

/** @ghidraAddress 0x7b08 */
int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([JubeatAppDelegate class]));
    }
}
