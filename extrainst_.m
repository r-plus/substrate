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

#include "Environment.hpp"

void SavePropertyList(CFPropertyListRef plist, char *path, CFURLRef url, CFPropertyListFormat format) {
    if (path[0] != '\0')
        url = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, (uint8_t *) path, strlen(path), false);
    CFWriteStreamRef stream = CFWriteStreamCreateWithFile(kCFAllocatorDefault, url);
    CFWriteStreamOpen(stream);
    CFPropertyListWriteToStream(plist, stream, format, NULL);
    CFWriteStreamClose(stream);
}

bool HookEnvironment(const char *path) {
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, (uint8_t *) path, strlen(path), false);

    CFPropertyListRef plist; {
        CFReadStreamRef stream = CFReadStreamCreateWithFile(kCFAllocatorDefault, url);
        CFReadStreamOpen(stream);
        plist = CFPropertyListCreateFromStream(kCFAllocatorDefault, stream, 0, kCFPropertyListMutableContainers, NULL, NULL);
        CFReadStreamClose(stream);
    }

    NSMutableDictionary *root = (NSMutableDictionary *) plist;
    if (root == nil)
        return false;
    NSMutableDictionary *ev = [root objectForKey:@"EnvironmentVariables"];
    if (ev == nil)
        return false;
    NSString *il = [ev objectForKey:@ SubstrateVariable_];
    if (il == nil)
        return false;
    NSArray *cm = [il componentsSeparatedByString:@":"];
    unsigned index = [cm indexOfObject:@ SubstrateLibrary_];
    if (index == INT_MAX)
        return false;
    NSMutableArray *cmm = [NSMutableArray arrayWithCapacity:16];
    [cmm addObjectsFromArray:cm];
    [cmm removeObject:@ SubstrateLibrary_];
    if ([cmm count] != 0)
        [ev setObject:[cmm componentsJoinedByString:@":"] forKey:@ SubstrateVariable_];
    else if ([ev count] == 1)
        [root removeObjectForKey:@"EnvironmentVariables"];
    else
        [ev removeObjectForKey:@ SubstrateVariable_];

    SavePropertyList(plist, "", url, kCFPropertyListBinaryFormat_v1_0);
    return true;
}

#define HookEnvironment(name) \
    HookEnvironment("/System/Library/LaunchDaemons/" name ".plist")

int main(int argc, char *argv[]) {
    if (argc < 2 || (
        strcmp(argv[1], "install") != 0 &&
        strcmp(argv[1], "upgrade") != 0 &&
    true)) return 0;

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    const char *finish = "restart";

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

    if (HookEnvironment("com.apple.SpringBoard"))
        finish = "reload";

    #define SubstrateCynject_ "/usr/bin/cynject 1 /Library/Frameworks/CydiaSubstrate.framework/Libraries/SubstrateLauncher.dylib"

    FILE *file = fopen("/etc/launchd.conf", "w+");
    fprintf(file, "bsexec .. " SubstrateCynject_);
    fclose(file);

    system(SubstrateCynject_);

    // XXX: damn you khan!
    finish = "reboot";

    const char *cydia = getenv("CYDIA");
    if (cydia != NULL) {
        int fd = [[[[NSString stringWithUTF8String:cydia] componentsSeparatedByString:@" "] objectAtIndex:0] intValue];
        FILE *fout = fdopen(fd, "w");
        fprintf(fout, "finish:%s\n", finish);
        fclose(fout);
    }

    [pool release];
    return 0;
}
