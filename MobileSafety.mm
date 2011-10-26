/* Cydia Substrate - Powerful Code Insertion Platform
 * Copyright (C) 2008-2011  Jay Freeman (saurik)
*/

/* GNU Lesser General Public License, Version 3 {{{ */
/*
 * Substrate is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * Substrate is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 * License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with Substrate.  If not, see <http://www.gnu.org/licenses/>.
**/
/* }}} */

%apt Package: com.saurik.substrate.safemode
%apt Author: Jay Freeman (saurik) <saurik@saurik.com>

%apt Name: Substrate Safe Mode
%apt Description: safe mode safety extension (safe)

%apt Depends: mobilesubstrate (>= 0.9.3367+38)

%fflag 1
%fflag 2

%bundle com.apple.springboard

%flag -framework Foundation
%flag -framework UIKit

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>
#import <UIKit/UIKit.h>

#include "CydiaSubstrate.h"

MSClassHook(UIStatusBar)

MSClassHook(UIImage)
MSMetaClassHook(UIImage)

MSClassHook(AAAccountManager)
MSMetaClassHook(AAAccountManager)

MSClassHook(BBSectionInfo)

MSClassHook(SBAlertItemsController)
MSClassHook(SBButtonBar)
MSClassHook(SBIconController)
MSClassHook(SBStatusBar)
MSClassHook(SBStatusBarDataManager)
MSClassHook(SBStatusBarTimeView)
MSClassHook(SBUIController)

Class $SafeModeAlertItem;

@interface SBAlertItem : NSObject {
}
- (UIAlertView *) alertSheet;
- (void) dismiss;
@end

@interface SBAlertItemsController : NSObject {
}
+ (SBAlertItemsController *) sharedInstance;
- (void) activateAlertItem:(SBAlertItem *)item;
@end

@interface SBStatusBarTimeView : UIView {
}
- (id) textFont;
@end

@interface UIApplication (CydiaSubstrate)
- (void) applicationOpenURL:(id)url;
@end

@interface UIAlertView (CydiaSubstrate)
- (void) setForceHorizontalButtonsLayout:(BOOL)force;
- (void) setBodyText:(NSString *)body;
- (void) setNumberOfRows:(NSInteger)rows;
@end

void SafeModeAlertItem$alertSheet$buttonClicked$(id self, SEL sel, id sheet, int button) {
    switch (button) {
        case 1:
        break;

        case 2:
            // XXX: there are better ways of restarting SpringBoard that would actually save state
            exit(0);
        break;

        case 3:
            [[UIApplication sharedApplication] applicationOpenURL:[NSURL URLWithString:@"http://cydia.saurik.com/safemode/"]];
        break;
    }

    [self dismiss];
}

void SafeModeAlertItem$configure$requirePasscodeForActions$(id self, SEL sel, BOOL configure, BOOL require) {
    UIAlertView *sheet([self alertSheet]);

    [sheet setDelegate:self];
    [sheet setBodyText:@"We apologize for the inconvenience, but SpringBoard has just crashed.\n\nMobileSubstrate /did not/ cause this problem: it has protected you from it.\n\nYour device is now running in Safe Mode. All extensions that support this safety system are disabled.\n\nReboot (or restart SpringBoard) to return to the normal mode. To return to this dialog touch the status bar.\n\nTap \"Help\" below for more tips."];
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


// XXX: on iOS 5.0, we really would prefer avoiding 

MSInstanceMessageHook2(void, SBStatusBar, touchesEnded,withEvent, id, touches, id, event) {
    MSAlert();
    MSOldCall(touches, event);
}

MSInstanceMessageHook1(void, SBStatusBar, mouseDown, void *, event) {
    MSAlert();
    MSOldCall(event);
}

MSInstanceMessageHook2(void, UIStatusBar, touchesBegan,withEvent, void *, touches, void *, event) {
    MSAlert();
    MSOldCall(touches, event);
}


// this fairly complex code came from Grant, to solve the "it Safe Mode"-in-bar bug

MSInstanceMessageHook0(void, SBStatusBarDataManager, _updateTimeString) {
    char *_data(&MSHookIvar<char>(self, "_data"));
    if (_data == NULL)
        return;

    Ivar _itemIsEnabled(object_getInstanceVariable(self, "_itemIsEnabled", NULL));
    if (_itemIsEnabled == NULL)
        return;

    Ivar _itemIsCloaked(object_getInstanceVariable(self, "_itemIsCloaked", NULL));
    if (_itemIsCloaked == NULL)
        return;

    size_t enabledOffset(ivar_getOffset(_itemIsEnabled));
    size_t cloakedOffset(ivar_getOffset(_itemIsCloaked));
    if (enabledOffset >= cloakedOffset)
        return;

    size_t offset(cloakedOffset - enabledOffset);
    char *timeString(_data + offset);
    strcpy(timeString, "Exit Safe Mode");
}


static bool alerted_;

static void AlertIfNeeded() {
    if (alerted_)
        return;
    alerted_ = true;
    MSAlert();
}


// on iOS 4.3 and above we can use this advertisement, which seems to check every time the user unlocks
// XXX: verify that this still works on iOS 5.0

MSClassMessageHook0(void, AAAccountManager, showMobileMeOfferIfNecessary) {
    AlertIfNeeded();
}


// -[SBIconController showInfoAlertIfNeeded] explains how to drag icons around the iPhone home screen
// it used to be shown to users when they unlocked their screen for the first time, and happened every unlock
// however, as of iOS 4.3, it got relegated to only appearing once the user installed an app or web clip

MSInstanceMessageHook0(void, SBIconController, showInfoAlertIfNeeded) {
    AlertIfNeeded();
}


// the icon state, including crazy configurations like Five Icon Dock, is stored in SpringBoard's defaults
// unfortunately, SpringBoard on iOS 2.0 and 2.1 (maybe 2.2 as well) buffer overrun with more than 4 icons
// there is a third party package called IconSupport that remedies this, but not everyone is using it yet

MSInstanceMessageHook0(int, SBButtonBar, maxIconColumns) {
    static int max;
    if (max == 0) {
        max = MSOldCall();
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


MSInstanceMessageHook0(id, SBUIController, init) {
    if ((self = MSOldCall()) != nil) {
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

#define Paper_ "/Library/MobileSubstrate/MobileSafety.png"

MSClassMessageHook0(UIImage *, UIImage, defaultDesktopImage) {
    return [UIImage imageWithContentsOfFile:@Paper_];
}

MSInstanceMessageHook0(void, SBStatusBarTimeView, tile) {
    NSString *&_time(MSHookIvar<NSString *>(self, "_time"));
    CGRect &_textRect(MSHookIvar<CGRect>(self, "_textRect"));
    if (_time != nil)
        [_time release];
    _time = [@"Exit Safe Mode" retain];
    id font([self textFont]);
    CGSize size([_time sizeWithFont:font]);
    CGRect frame([self frame]);
    _textRect.size = size;
    _textRect.origin.x = (frame.size.width - size.width) / 2;
    _textRect.origin.y = (frame.size.height - size.height) / 2;
}


// notification widgets ("wee apps" or "bulletin board sections") are capable of crashing SpringBoard
// unfortunately, which ones are in use are stored in SpringBoard's defaults, so we need to turn them off

MSInstanceMessageHook0(BOOL, BBSectionInfo, showsInNotificationCenter) {
    return NO;
}
