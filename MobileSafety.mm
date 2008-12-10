/* Cydia Substrate - Meta-Library Insert for iPhoneOS
 * Copyright (C) 2008  Jay Freeman (saurik)
*/

/*
 *        Redistribution and use in source and binary
 * forms, with or without modification, are permitted
 * provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the
 *    above copyright notice, this list of conditions
 *    and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the
 *    above copyright notice, this list of conditions
 *    and the following disclaimer in the documentation
 *    and/or other materials provided with the
 *    distribution.
 * 3. The name of the author may not be used to endorse
 *    or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,
 * BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
 * TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>

#include <substrate.h>

@protocol MobileSubstrate
- (id) sharedInstance;
- (void) activateAlertItem:(id)item;
- (id) initWithTitle:(NSString *)title body:(NSString *)body;
- (id) ms$initWithSize:(CGSize)size;
- (void) ms$drawRect:(CGRect)rect;
- (id) darkGrayColor;
- (void) setBackgroundColor:(id)color;
- (int) ms$maxIconColumns;
@end

static void MSAlert(id self, SEL sel) {
    static bool loaded = false;
    if (!loaded)
        loaded = true;
    else return;

    [[(id) objc_getClass("SBAlertItemsController") sharedInstance] activateAlertItem:
        [[(id) objc_getClass("SBDismissOnlyAlertItem") alloc]
            initWithTitle:@"Mobile Substrate Safe Mode"
            body:@"We apologize for the inconvenience, but SpringBoard has just crashed.\n\nA recent software installation, upgrade, or removal might have been the cause of this.\n\nIf you are using IntelliScreen, then it probably crashed.\n\nYour device is now running in Safe Mode. All extensions that support this safety system are disabled.\n\nReboot (or restart SpringBoard) to return to the normal mode."
    ]];
}

static int SBButtonBar$maxIconColumns(id<MobileSubstrate> self, SEL sel) {
    static int max;
    if (max == 0) {
        max = [self ms$maxIconColumns];
        if (NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults])
            if (NSDictionary *iconState = [defaults objectForKey:@"iconState"])
                if (NSDictionary *buttonBar = [iconState objectForKey:@"buttonBar"])
                    if (NSArray *iconMatrix = [buttonBar objectForKey:@"iconMatrix"])
                        if ([iconMatrix count] != 0)
                            if (NSArray *row = [iconMatrix objectAtIndex:0]) {
                                int count([row count]);
                                if (max < count)
                                    max = count;
                            }
    } return max;
}

static id SBContentLayer$initWithSize$(id<MobileSubstrate> self, SEL sel, CGSize size) {
    self = [self ms$initWithSize:size];
    if (self == nil)
        return nil;
    [self setBackgroundColor:[(id) objc_getClass("UIColor") darkGrayColor]];
    return self;
}

static void SBStatusBarTimeView$drawRect$(id<MobileSubstrate> self, SEL sel, CGRect rect) {
    id &_time(MSHookIvar<id>(self, "_time"));
    if (_time != nil)
        [_time autorelease];
    _time = [@"Safe Mode" retain];
    return [self ms$drawRect:rect];
}

#define Dylib_ "/Library/MobileSubstrate/MobileSubstrate.dylib"

extern "C" void MSSafety() {
    NSLog(@"MS:Warning: Entering Safe Mode");

    MSHookMessage(objc_getClass("SBButtonBar"), @selector(maxIconColumns), (IMP) &SBButtonBar$maxIconColumns, "ms$");
    MSHookMessage(objc_getClass("SBContentLayer"), @selector(initWithSize:), (IMP) &SBContentLayer$initWithSize$, "ms$");
    MSHookMessage(objc_getClass("SBStatusBarTimeView"), @selector(drawRect:), (IMP) &SBStatusBarTimeView$drawRect$, "ms$");

    char *dil = getenv("DYLD_INSERT_LIBRARIES");
    if (dil == NULL)
        NSLog(@"MS:Error: DYLD_INSERT_LIBRARIES is unset?");
    else {
        NSArray *dylibs([[NSString stringWithUTF8String:dil] componentsSeparatedByString:@":"]);
        NSUInteger index([dylibs indexOfObject:@ Dylib_]);
        if (index == NSNotFound)
            NSLog(@"MS:Error: dylib not in DYLD_INSERT_LIBRARIES?");
        else if ([dylibs count] == 1)
            unsetenv("DYLD_INSERT_LIBRARIES");
        else {
            NSMutableArray *value([[[NSMutableArray alloc] init] autorelease]);
            [value setArray:dylibs];
            [value removeObjectAtIndex:index];
            setenv("DYLD_INSERT_LIBRARIES", [[value componentsJoinedByString:@":"] UTF8String], !0);
        }
    }

    if (Class _class = objc_getClass("SBIconController")) {
        SEL sel(@selector(showInfoAlertIfNeeded));
        if (Method method = class_getInstanceMethod(_class, sel))
            method_setImplementation(method, (IMP) &MSAlert);
    }
}
