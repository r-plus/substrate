#include <CoreFoundation/CFPropertyList.h>
#import <Foundation/Foundation.h>
#include <string.h>
#include <stdint.h>

void SavePropertyList(CFPropertyListRef plist, char *path, CFURLRef url, CFPropertyListFormat format) {
    if (path[0] != '\0')
        url = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, (uint8_t *) path, strlen(path), false);
    CFWriteStreamRef stream = CFWriteStreamCreateWithFile(kCFAllocatorDefault, url);
    CFWriteStreamOpen(stream);
    CFPropertyListWriteToStream(plist, stream, format, NULL);
    CFWriteStreamClose(stream);
}

#define dylib_ @"/Library/MobileSubstrate/MobileSubstrate.dylib"
#define itunesstored_plist "/System/Library/LaunchDaemons/com.apple.itunesstored.plist"
#define mediaserverd_plist "/System/Library/LaunchDaemons/com.apple.mediaserverd.plist"
#define CommCenter_plist "/System/Library/LaunchDaemons/com.apple.CommCenter.plist"
#define AOSNotification_plist "/System/Library/LaunchDaemons/com.apple.AOSNotification.plist"
#define BTServer_plist "/System/Library/LaunchDaemons/com.apple.BTServer.plist"
#define iapd_plist "/System/Library/LaunchDaemons/com.apple.iapd.plist"
#define lsd_plist "/System/Library/LaunchDaemons/com.apple.lsd.plist"

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
    NSString *il = [ev objectForKey:@"DYLD_INSERT_LIBRARIES"];
    if (il == nil)
        return false;
    NSArray *cm = [il componentsSeparatedByString:@":"];
    unsigned index = [cm indexOfObject:dylib_];
    if (index == INT_MAX)
        return false;
    NSMutableArray *cmm = [NSMutableArray arrayWithCapacity:16];
    [cmm addObjectsFromArray:cm];
    [cmm removeObject:dylib_];
    if ([cmm count] != 0)
        [ev setObject:[cmm componentsJoinedByString:@":"] forKey:@"DYLD_INSERT_LIBRARIES"];
    else if ([ev count] == 1)
        [root removeObjectForKey:@"EnvironmentVariables"];
    else
        [ev removeObjectForKey:@"DYLD_INSERT_LIBRARIES"];

    SavePropertyList(plist, "", url, kCFPropertyListBinaryFormat_v1_0);
    return true;
}

int main(int argc, char *argv[]) {
    if (argc < 2 || (
        strcmp(argv[1], "abort-install") != 0 &&
        strcmp(argv[1], "remove") != 0
    )) return 0;

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    // XXX: do not use for now due to later reboot
    #define HookEnvironment_(plist) \
        if (HookEnvironment(plist)) \
            system("launchctl unload "plist"; launchctl load "plist"");

    HookEnvironment(itunesstored_plist);
    HookEnvironment(mediaserverd_plist);
    HookEnvironment(CommCenter_plist);
    HookEnvironment(AOSNotification_plist);
    HookEnvironment(BTServer_plist);
    HookEnvironment(iapd_plist);
    HookEnvironment(lsd_plist);

    const char *finish = "restart";
    if (HookEnvironment("/System/Library/LaunchDaemons/com.apple.SpringBoard.plist"))
        finish = "reload";

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
