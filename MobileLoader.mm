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

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <dlfcn.h>
#include <unistd.h>

#include <objc/runtime.h>

static char MSWatch[PATH_MAX];

static void MSAction(int sig, siginfo_t *info, void *uap) {
    open(MSWatch, O_CREAT | O_RDWR, 0644);
    raise(sig);
}

#define Safety_ @"/Library/MobileSubstrate/MobileSafety.dylib"

extern "C" void MSInitialize() {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSBundle *bundle([NSBundle mainBundle]);
    NSString *identifier(bundle == nil ? nil : [bundle bundleIdentifier]);
    if (identifier == nil)
        goto pool;
    {
        NSLog(@"MS:Notice: Installing: %@", identifier);

        NSString *watch = [[[NSHomeDirectory()
            stringByAppendingPathComponent:@"Library"]
            stringByAppendingPathComponent:@"Preferences"]
            stringByAppendingPathComponent:@"com.saurik.mobilesubstrate.dat"]
        ; strcpy(MSWatch, [watch UTF8String]);

        NSFileManager *manager = [NSFileManager defaultManager];

        if ([identifier isEqualToString:@"com.apple.springboard"]) {
            if ([manager fileExistsAtPath:watch]) {
                NSError *error = NULL;
                if (![manager removeItemAtPath:watch error:&error])
                    NSLog(@"MS:Error: Cannot Clear: %@", error);
                void *handle = dlopen([Safety_ UTF8String], RTLD_LAZY | RTLD_GLOBAL);
                if (handle == NULL)
                    NSLog(@"MS:Error: Cannot Load: %s", dlerror());
                goto pool;
            }

            stack_t stack;
            stack.ss_size = 8*1024;
            stack.ss_flags = 0;
            stack.ss_sp = malloc(stack.ss_size);

            bool stacked = false;
            if (stack.ss_sp != NULL) {
                if (sigaltstack(&stack, NULL) != -1)
                    stacked = true;
                else
                    NSLog(@"MS:Error: Cannot Stack: %s", strerror(errno));
            }

            struct sigaction action;
            memset(&action, 0, sizeof(action));
            action.sa_sigaction = &MSAction;
            action.sa_flags = SA_SIGINFO | SA_RESETHAND;
            if (stacked)
                action.sa_flags |= SA_ONSTACK;
            sigemptyset(&action.sa_mask);

            sigaction(SIGTRAP, &action, NULL);
            sigaction(SIGABRT, &action, NULL);
            sigaction(SIGILL, &action, NULL);
            sigaction(SIGBUS, &action, NULL);
            sigaction(SIGSEGV, &action, NULL);
        }

        NSString *dylibs(@"/Library/MobileSubstrate/DynamicLibraries");

        for (NSString *dylib in [manager contentsOfDirectoryAtPath:dylibs error:NULL]) {
            if (![dylib hasSuffix:@".dylib"])
                continue;
            NSString *base([[dylibs stringByAppendingPathComponent:dylib] stringByDeletingPathExtension]);

            NSString *plist([base stringByAppendingPathExtension:@"plist"]);
            NSDictionary *meta = [[NSDictionary alloc] initWithContentsOfFile:plist];
            if (meta != nil) {
                [meta autorelease];

                if (NSDictionary *filter = [meta objectForKey:@"Filter"]) {
                    if (NSArray *bundles = [filter objectForKey:@"Bundles"])
                        for (NSString *bundle in bundles)
                            if ([NSBundle bundleWithIdentifier:bundle])
                                goto load;
                    continue;
                } load:
            ;}

            NSLog(@"MS:Notice: Loading: %@", dylib);

            NSString *path([dylibs stringByAppendingPathComponent:dylib]);
            void *handle = dlopen([path UTF8String], RTLD_LAZY | RTLD_GLOBAL);
            if (handle == NULL) {
                NSLog(@"MS:Error: %s", dlerror());
                continue;
            }
        }
    }

  pool:
    [pool release];
}
