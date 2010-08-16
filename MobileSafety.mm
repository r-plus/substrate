/* Cydia Substrate - Powerful Code Insertion Platform
 * Copyright (C) 2008-2010  Jay Freeman (saurik)
*/

/* GNU Lesser General Public License, Version 3 {{{ */
/*
 * Cycript is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * Cycript is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 * License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with Cycript.  If not, see <http://www.gnu.org/licenses/>.
**/
/* }}} */

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>
#import <UIKit/UIKit.h>

#import <SpringBoard/SBAlertItem.h>
#import <SpringBoard/SBAlertItemsController.h>
#import <SpringBoard/SBButtonBar.h>
#import <SpringBoard/SBStatusBarController.h>
#import <SpringBoard/SBStatusBarDataManager.h>
#import <SpringBoard/SBStatusBarTimeView.h>
#import <SpringBoard/SBUIController.h>

#include <substrate.h>

Class $SafeModeAlertItem;
Class $SBAlertItemsController;

void SafeModeAlertItem$alertSheet$buttonClicked$(id self, SEL sel, id sheet, int button) {
    switch (button) {
        case 1:
        break;

        case 2:
            exit(0);
        break;

        case 3:
            [UIApp applicationOpenURL:[NSURL URLWithString:@"http://cydia.saurik.com/safemode/"]];
        break;
    }

    [self dismiss];
}

void SafeModeAlertItem$configure$requirePasscodeForActions$(id self, SEL sel, BOOL configure, BOOL require) {
    id sheet([self alertSheet]);
    [sheet setDelegate:self];
    [sheet setBodyText:@"We apologize for the inconvenience, but SpringBoard has just crashed.\n\nMobileSubstrate /did not/ cause this problem: it has protected you from it.\n\nYour device is now running in Safe Mode. All extensions that support this safety system are disabled.\n\nReboot (or restart SpringBoard) to return to the normal mode. To return to this dialog touch the status bar."];
    [sheet addButtonWithTitle:@"OK"];
    [sheet addButtonWithTitle:@"Restart"];
    [sheet addButtonWithTitle:@"Help"];
    [sheet setNumberOfRows:1];
    if ([sheet respondsToSelector:@selector(setForceHorizontalButtonsLayout:)])
        [sheet setForceHorizontalButtonsLayout:YES];
}

void SafeModeAlertItem$performUnlockAction(id self, SEL sel) {
    [[$SBAlertItemsController sharedInstance] activateAlertItem:self];
}

static void MSAlert() {
    if ($SafeModeAlertItem == nil)
        $SafeModeAlertItem = objc_lookUpClass("SafeModeAlertItem");
    if ($SafeModeAlertItem == nil) {
        $SafeModeAlertItem = objc_allocateClassPair(objc_getClass("SBAlertItem"), "SafeModeAlertItem", 0);
        if ($SafeModeAlertItem == nil)
            return;

        class_addMethod($SafeModeAlertItem, @selector(alertSheet:buttonClicked:), (IMP) &SafeModeAlertItem$alertSheet$buttonClicked$, "v@:@i");
        class_addMethod($SafeModeAlertItem, @selector(configure:requirePasscodeForActions:), (IMP) &SafeModeAlertItem$configure$requirePasscodeForActions$, "v@:cc");
        class_addMethod($SafeModeAlertItem, @selector(performUnlockAction), (IMP) SafeModeAlertItem$performUnlockAction, "v@:");
        objc_registerClassPair($SafeModeAlertItem);
    }

    if ($SBAlertItemsController != nil)
        [[$SBAlertItemsController sharedInstance] activateAlertItem:[[[$SafeModeAlertItem alloc] init] autorelease]];
}

MSHook(void, SBStatusBar$touchesEnded$withEvent$, SBStatusBar *self, SEL sel, id touches, id event) {
    MSAlert();
    _SBStatusBar$touchesEnded$withEvent$(self, sel, touches, event);
}

MSHook(void, SBStatusBar$mouseDown$, SBStatusBar *self, SEL sel, GSEventRef event) {
    MSAlert();
    _SBStatusBar$mouseDown$(self, sel, event);
}

MSHook(void, UIStatusBar$touchesBegan$withEvent$, id self, SEL sel, void *arg0, void *arg1) {
    MSAlert();
    _UIStatusBar$touchesBegan$withEvent$(self, sel, arg0, arg1);
}

MSHook(void, SBStatusBarDataManager$_updateTimeString, id self, SEL sel) {
    if (char *_data = &MSHookIvar<char>(self, "_data")) {
        char *timeString(_data + 20);
        strcpy(timeString, "Exit Safe Mode");
    }
}

static void SBIconController$showInfoAlertIfNeeded(id self, SEL sel) {
    static bool loaded = false;
    if (loaded)
        return;
    loaded = true;
    MSAlert();
}

MSHook(int, SBButtonBar$maxIconColumns, SBButtonBar *self, SEL sel) {
    static int max;
    if (max == 0) {
        max = _SBButtonBar$maxIconColumns(self, sel);
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

MSHook(id, SBUIController$init, SBUIController *self, SEL sel) {
    if ((self = _SBUIController$init(self, sel)) != nil) {
        UIView *&_contentLayer(MSHookIvar<UIView *>(self, "_contentLayer"));
        UIView *&_contentView(MSHookIvar<UIView *>(self, "_contentView"));

        UIView *layer;
        if (&_contentLayer != NULL)
            layer = _contentLayer;
        else if (&_contentView != NULL)
            layer = _contentView;
        else
            layer = nil;

        if (layer != nil)
            [layer setBackgroundColor:[UIColor darkGrayColor]];
    } return self;
}

#define Paper_ "/Library/MobileSubstrate/MobilePaper.png"

MSHook(UIImage *, UIImage$defaultDesktopImage, UIImage *self, SEL sel) {
    return [UIImage imageWithContentsOfFile:@Paper_];
}

MSHook(void, SBStatusBarTimeView$tile, SBStatusBarTimeView *self, SEL sel) {
    NSString *&_time(MSHookIvar<NSString *>(self, "_time"));
    CGRect &_textRect(MSHookIvar<CGRect>(self, "_textRect"));
    if (_time != nil)
        [_time release];
    _time = [@"Exit Safe Mode" retain];
    GSFontRef font([self textFont]);
    CGSize size([_time sizeWithFont:(id)font]);
    CGRect frame([self frame]);
    _textRect.size = size;
    _textRect.origin.x = (frame.size.width - size.width) / 2;
    _textRect.origin.y = (frame.size.height - size.height) / 2;
}

#define Dylib_ "/Library/MobileSubstrate/MobileSubstrate.dylib"

MSInitialize {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSLog(@"MS:Warning: Entering Safe Mode");

    _SBButtonBar$maxIconColumns = MSHookMessage(objc_getClass("SBButtonBar"), @selector(maxIconColumns), &$SBButtonBar$maxIconColumns);
    _SBUIController$init = MSHookMessage(objc_getClass("SBUIController"), @selector(init), &$SBUIController$init);
    _SBStatusBar$touchesEnded$withEvent$ = MSHookMessage(objc_getClass("SBStatusBar"), @selector(touchesEnded:withEvent:), &$SBStatusBar$touchesEnded$withEvent$);
    _SBStatusBar$mouseDown$ = MSHookMessage(objc_getClass("SBStatusBar"), @selector(mouseDown:), &$SBStatusBar$mouseDown$);
    _SBStatusBarDataManager$_updateTimeString = MSHookMessage(objc_getClass("SBStatusBarDataManager"), @selector(_updateTimeString), &$SBStatusBarDataManager$_updateTimeString);
    _SBStatusBarTimeView$tile = MSHookMessage(objc_getClass("SBStatusBarTimeView"), @selector(tile), &$SBStatusBarTimeView$tile);

    _UIStatusBar$touchesBegan$withEvent$ = MSHookMessage(objc_getClass("UIStatusBar"), @selector(touchesBegan:withEvent:), &$UIStatusBar$touchesBegan$withEvent$);

    _UIImage$defaultDesktopImage = MSHookMessage(object_getClass(objc_getClass("UIImage")), @selector(defaultDesktopImage), &$UIImage$defaultDesktopImage);

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

    $SBAlertItemsController = objc_getClass("SBAlertItemsController");

    if (Class _class = objc_getClass("SBIconController")) {
        SEL sel(@selector(showInfoAlertIfNeeded));
        if (Method method = class_getInstanceMethod(_class, sel))
            method_setImplementation(method, (IMP) &SBIconController$showInfoAlertIfNeeded);
    }

    [pool release];
}
