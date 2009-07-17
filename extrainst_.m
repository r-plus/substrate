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
    if (ev == nil) {
        ev = [NSMutableDictionary dictionaryWithCapacity:16];
        [root setObject:ev forKey:@"EnvironmentVariables"];
    }
    NSString *il = [ev objectForKey:@"DYLD_INSERT_LIBRARIES"];
    if (il == nil || [il length] == 0)
        [ev setObject:dylib_ forKey:@"DYLD_INSERT_LIBRARIES"];
    else {
        NSArray *cm = [il componentsSeparatedByString:@":"];
        unsigned index = [cm indexOfObject:dylib_];
        if (index != INT_MAX)
            return false;
        [ev setObject:[NSString stringWithFormat:@"%@:%@", il, dylib_] forKey:@"DYLD_INSERT_LIBRARIES"];
    }

    SavePropertyList(plist, "", url, kCFPropertyListBinaryFormat_v1_0);
    return true;
}

int main(int argc, char *argv[]) {
    if (argc < 2 || (
        strcmp(argv[1], "upgrade") != 0 &&
        strcmp(argv[1], "install") != 0
    ))
        return 0;

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    if (HookEnvironment(itunesstored_plist))
        system("launchctl unload "itunesstored_plist"; launchctl load "itunesstored_plist"");

    const char *finish = "restart";
    if (HookEnvironment("/System/Library/LaunchDaemons/com.apple.SpringBoard.plist"))
        finish = "reload";

    const char *cydia = getenv("CYDIA");
    if (cydia != NULL) {
        int fd = [[[[NSString stringWithUTF8String:cydia] componentsSeparatedByString:@" "] objectAtIndex:0] intValue];
        FILE *fout = fdopen(fd, "w");
        fprintf(fout, "finish:%s\n", finish);
        fclose(fout);
    }

    //system("/usr/libexec/cydia/move.sh /Library/MobileSubstrate/DynamicLibraries");

    [pool release];
    return 0;
}
