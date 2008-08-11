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

#define plist_ "/System/Library/LaunchDaemons/com.apple.SpringBoard.plist"
#define dylib_ @"/Library/MobileSubstrate/MobileSubstrate.dylib"

int main(int argc, char *argv[]) {
    if (argc < 2 || (
        strcmp(argv[1], "abort-install") != 0 &&
        strcmp(argv[1], "remove") != 0
    )) return 0;

    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    CFURLRef url = CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, (uint8_t *) plist_, strlen(plist_), false);

    CFPropertyListRef plist; {
        CFReadStreamRef stream = CFReadStreamCreateWithFile(kCFAllocatorDefault, url);
        CFReadStreamOpen(stream);
        plist = CFPropertyListCreateFromStream(kCFAllocatorDefault, stream, 0, kCFPropertyListMutableContainers, NULL, NULL);
        CFReadStreamClose(stream);
    }

    const char *finish = "restart";

    NSMutableDictionary *root = (NSMutableDictionary *) plist;
    if (root == nil)
        goto quick;
    NSMutableDictionary *ev = [root objectForKey:@"EnvironmentVariables"];
    if (ev == nil)
        goto quick;
    NSString *il = [ev objectForKey:@"DYLD_INSERT_LIBRARIES"];
    if (il == nil)
        goto quick;
    NSArray *cm = [il componentsSeparatedByString:@":"];
    unsigned index = [cm indexOfObject:dylib_];
    if (index == INT_MAX)
        goto quick;
    NSMutableArray *cmm = [NSMutableArray arrayWithCapacity:16];
    [cmm addObjectsFromArray:cm];
    [cmm removeObject:dylib_];
    if ([cmm count] != 0)
        [ev setObject:[cmm componentsJoinedByString:@":"] forKey:@"DYLD_INSERT_LIBRARIES"];
    else if ([ev count] == 1)
        [root removeObjectForKey:@"EnvironmentVariables"];
    else
        [ev removeObjectForKey:@"DYLD_INSERT_LIBRARIES"];

    SavePropertyList(plist, "", url, kCFPropertyListXMLFormat_v1_0);

    finish = "reload";
  quick:;

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
