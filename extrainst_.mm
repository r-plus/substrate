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

#include <CoreFoundation/CFPropertyList.h>
#import <Foundation/Foundation.h>
#include <string.h>
#include <stdint.h>

#include "Cydia.hpp"
#include "Environment.hpp"
#include "LaunchDaemons.hpp"

#ifdef __arm__

// XXX: NO means "failed", false means "unneeded"

static bool HookEnvironment(const char *name) {
    NSString *file([NSString stringWithFormat:@"%@/%s.plist", @ SubstrateLaunchDaemons_, name]);
    if (file == nil)
        return NO;

    NSMutableDictionary *root([NSMutableDictionary dictionaryWithContentsOfFile:file]);
    if (root == nil)
        return NO;

    NSMutableDictionary *environment([root objectForKey:@"EnvironmentVariables"]);
    if (environment == nil) {
        environment = [NSMutableDictionary dictionaryWithCapacity:1];
        if (environment == nil)
            return NO;

        [root setObject:environment forKey:@"EnvironmentVariables"];
    }

    NSString *variable([environment objectForKey:@ SubstrateVariable_]);
    if (variable == nil || [variable length] == 0)
        [environment setObject:@ SubstrateLibrary_ forKey:@ SubstrateVariable_];
    else {
        NSArray *dylibs([variable componentsSeparatedByString:@":"]);
        if (dylibs == nil)
            return NO;

        NSUInteger index([dylibs indexOfObject:@ SubstrateLibrary_]);
        if (index != NSNotFound)
            return false;

        [environment setObject:[NSString stringWithFormat:@"%@:%@", variable, @ SubstrateLibrary_] forKey:@ SubstrateVariable_];
    }

    NSString *error;
    NSData *data([NSPropertyListSerialization dataFromPropertyList:root format:NSPropertyListBinaryFormat_v1_0 errorDescription:&error]);
    if (data == nil)
        return NO;

    if (![data writeToFile:file atomically:YES])
        return NO;

    return true;
}

static int InstallTether() {
    HookEnvironment("com.apple.mediaserverd");
    HookEnvironment("com.apple.itunesstored");
    HookEnvironment("com.apple.CommCenter");
    HookEnvironment("com.apple.AOSNotification");

    HookEnvironment("com.apple.BTServer");
    HookEnvironment("com.apple.iapd");

    HookEnvironment("com.apple.lsd");
    HookEnvironment("com.apple.imagent");

    HookEnvironment("com.apple.mobile.lockdown");
    HookEnvironment("com.apple.itdbprep.server");

    HookEnvironment("com.apple.locationd");

    HookEnvironment("com.apple.mediaremoted");
    HookEnvironment("com.apple.frontrow");

    HookEnvironment("com.apple.voiced");
    HookEnvironment("com.apple.MobileInternetSharing");

    HookEnvironment("com.apple.CommCenterClassic");
    HookEnvironment("com.apple.gamed");

    HookEnvironment("com.apple.mobile.softwareupdated");
    HookEnvironment("com.apple.softwareupdateservicesd");
    HookEnvironment("com.apple.twitterd");
    HookEnvironment("com.apple.mediaremoted");

    HookEnvironment("com.apple.assistivetouchd");
    HookEnvironment("com.apple.accountsd");

    HookEnvironment("com.apple.configd");
    HookEnvironment("com.apple.wifid");
    HookEnvironment("com.apple.mobile.installd");

    HookEnvironment("com.apple.SpringBoard");

    FinishCydia("reboot");

    return 0;
}

#endif

static int InstallSemiTether() {
    MSClearLaunchDaemons();

    NSFileManager *manager([NSFileManager defaultManager]);
    NSError *error;


    // we must copy the dylib to a new filename in order to guarantee that dlopen() considers it to be different
    // if we fail to do this, it is quite unfortunate, but often it will work to use the original name

    NSString *temp([NSString stringWithFormat:@"/tmp/ms-%f.dylib", [[NSDate date] timeIntervalSinceReferenceDate]]);

    NSString *dylib;
    if ([manager copyItemAtPath:@ SubstrateLauncher_ toPath:temp error:&error])
        dylib = temp;
    else {
        fprintf(stderr, "unable to copy: %s\n", [[error description] UTF8String]);
        // XXX: this is not actually reasonable
        dylib = @ SubstrateLauncher_;
        temp = nil;
    }


    // XXX: check the result code and do something about failures
    system([[@"/usr/bin/cynject 1 " stringByAppendingString:dylib] UTF8String]);


    // if we are unable to remove the file copied into /tmp, it is interesting, but harmless

    if (temp != nil && ![manager removeItemAtPath:temp error:&error])
        if (unlink([temp UTF8String]) == -1)
            fprintf(stderr, "unable to remove: (%s):%d\n", [[error description] UTF8String], errno);


    NSString *config([NSString stringWithContentsOfFile:@ SubstrateLaunchConfig_ encoding:NSNonLossyASCIIStringEncoding error:&error]);
    // XXX: if the file fails to load, it might not be missing: it might be unreadable for some reason
    if (config == nil)
        config = @"";

    NSArray *lines([config componentsSeparatedByString:@"\n"]);
    NSMutableArray *copy([lines mutableCopy]);

    [copy removeObject:@""];

    if ([lines indexOfObject:@ SubstrateBootstrapExecute_] == NSNotFound)
        [copy addObject:@ SubstrateBootstrapExecute_];

    [copy addObject:@""];

    if (![copy isEqualToArray:lines])
        [[copy componentsJoinedByString:@"\n"] writeToFile:@ SubstrateLaunchConfig_ atomically:YES encoding:NSNonLossyASCIIStringEncoding error:&error];

    return 0;
}

#ifdef __arm__

static int InstallQuasiTether() {
    // JailbreakMe 3.0 "Saffron" bootstrapped itself using /usr/libexec/dirhelper
    // unfortunately, dirhelper is run too long after launchd.conf is processed
    // here we detect whether dirhelper is /boot/untether so as to install tethered

    // further, Saffron used a special filesystem called "unionfs" instead of stashing
    // this prevents us from easily being able to make modifications to the injector
    // it should be noted that we cannot use launchd.conf itself, also due to unionfs
    // however, comex implemented rename() to work on files in situ (under the mount)
    // XXX: this means we might be able to rename dirhelper a different injection

    char dirhelper[1024];
    memset(dirhelper, 0, sizeof(dirhelper));

    // we use sizeof(dirhelper) - 1, as readlink() does not NUL-terminate the buffer

    if (readlink("/usr/libexec/dirhelper", dirhelper, sizeof(dirhelper) - 1) > 0)
        if (strcmp(dirhelper, "/boot/untether") == 0)
            return InstallTether();


    // there is a horrible bug in some jailbreaks where fork() causes dirty pages to become codesign invalid
    // as our posix_spawn hook in launchd occurs after a call to fork(), we cannot use that injection mechanism

    switch (DetectForkBug()) {
        case ForkBugUnknown:
            return 1;

        case ForkBugPresent:
            return InstallTether();

        case ForkBugMissing:
            break;
    }

    return InstallSemiTether();
}

#endif

int main(int argc, char *argv[]) {
    if (argc < 2 || (
        strcmp(argv[1], "install") != 0 &&
        strcmp(argv[1], "upgrade") != 0 &&
    true)) return 0;

    NSAutoreleasePool *pool([[NSAutoreleasePool alloc] init]);

#ifdef __arm__
    int result(InstallQuasiTether());
#else
    int result(InstallSemiTether());
#endif

    [pool release];

    // XXX: in general, this return 0 happens way too often
    return result;
}
