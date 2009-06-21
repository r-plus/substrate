/* Cydia Substrate - Meta-Library Insert for iPhoneOS
 * Copyright (C) 2008-2009  Jay Freeman (saurik)
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
#import <CoreFoundation/CFPriv.h>

#import <Foundation/Foundation.h>
#import <CoreGraphics/CGGeometry.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <dlfcn.h>
#include <unistd.h>

#include <objc/runtime.h>
#include <substrate.h>

#define ForSaurik 0

#define CFLog(args...) \
    do { \
        CFStringRef string(CFStringCreateWithFormat(kCFAllocatorDefault, NULL, args)); \
        CFShow(string); \
        CFRelease(string); \
    } while(0)

static char MSWatch[PATH_MAX];

static void MSAction(int sig, siginfo_t *info, void *uap) {
    open(MSWatch, O_CREAT | O_RDWR, 0644);
    raise(sig);
}

#define Libraries_ "/Library/MobileSubstrate/DynamicLibraries"
#define Safety_ "/Library/MobileSubstrate/MobileSafety.dylib"

extern "C" int __fdnlist(int fd, struct nlist *list);
extern "C" int $__fdnlist(int fd, struct nlist *list);
//extern "C" int $nlist(const char *file, struct nlist *list);

extern "C" void MSInitialize() {
    if (dlopen(Foundation_f, RTLD_LAZY | RTLD_NOLOAD) == NULL)
        return;
    CFBundleRef bundle(CFBundleGetMainBundle());
    CFStringRef identifier(bundle == NULL ? NULL : CFBundleGetIdentifier(bundle));
    if (identifier == NULL)
        return;

    CFLog(CFSTR("MS:Notice: Installing: %@"), identifier);

    if (CFEqual(identifier, CFSTR("com.apple.springboard"))) {
        CFURLRef home(CFCopyHomeDirectoryURLForUser(NULL));
        CFURLGetFileSystemRepresentation(home, TRUE, reinterpret_cast<UInt8 *>(MSWatch), sizeof(MSWatch));
        CFRelease(home);
        strcat(MSWatch, "/Library/Preferences/com.saurik.mobilesubstrate.dat");

        if (access(MSWatch, R_OK) == 0) {
            if (unlink(MSWatch) == -1)
                CFLog(CFSTR("MS:Error: Cannot Clear: %s"), strerror(errno));

            void *handle(dlopen(Safety_, RTLD_LAZY | RTLD_GLOBAL));
            if (handle == NULL)
                CFLog(CFSTR("MS:Error: Cannot Load: %s"), dlerror());

            return;
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
                CFLog(CFSTR("MS:Error: Cannot Stack: %s"), strerror(errno));
        }

        struct sigaction action;
        memset(&action, 0, sizeof(action));
        action.sa_sigaction = &MSAction;
        action.sa_flags = SA_SIGINFO | SA_RESETHAND;
        if (stacked)
            action.sa_flags |= SA_ONSTACK;
        sigemptyset(&action.sa_mask);

        struct sigaction old;

#define HookSignal(signum) \
sigaction(signum, NULL, &old); { \
    sigaction(signum, &action, NULL); \
}

        HookSignal(SIGTRAP)
        HookSignal(SIGABRT)
        HookSignal(SIGILL)
        HookSignal(SIGBUS)
        HookSignal(SIGSEGV)
    }

    CFLog(CFSTR("MS:Notice: Hooking: nlist()"));
    MSHookFunction(&__fdnlist, &$__fdnlist);
    //MSHookFunction(&nlist, &$nlist);

    CFURLRef libraries(CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, reinterpret_cast<const UInt8 *>(Libraries_), sizeof(Libraries_) - 1, TRUE));

    CFBundleRef folder(CFBundleCreate(kCFAllocatorDefault, libraries));
    CFRelease(libraries);

    if (folder == NULL)
        return;

    CFArrayRef dylibs(CFBundleCopyResourceURLsOfType(folder, CFSTR("dylib"), NULL));
    CFRelease(folder);

    for (CFIndex i(0), count(CFArrayGetCount(dylibs)); i != count; ++i) {
        CFURLRef dylib(reinterpret_cast<CFURLRef>(CFArrayGetValueAtIndex(dylibs, i)));

        char path[PATH_MAX];
        CFURLGetFileSystemRepresentation(dylib, TRUE, reinterpret_cast<UInt8 *>(path), sizeof(path));
        size_t length(strlen(path));
        memcpy(path + length - 5, "plist", 5);

        CFURLRef plist(CFURLCreateFromFileSystemRepresentation(kCFAllocatorDefault, reinterpret_cast<UInt8 *>(path), length, FALSE));

        CFDataRef data;
        if (!CFURLCreateDataAndPropertiesFromResource(kCFAllocatorDefault, plist, &data, NULL, NULL, NULL))
            data = NULL;
        CFRelease(plist);

        CFDictionaryRef meta(NULL);
        if (data != NULL) {
            CFStringRef error;
            meta = reinterpret_cast<CFDictionaryRef>(CFPropertyListCreateFromXMLData(kCFAllocatorDefault, data, kCFPropertyListImmutable, &error));
        }

        bool load;
        if (meta == NULL)
            load = true;
        else {
            load = false;

            if (CFDictionaryRef filter = reinterpret_cast<CFDictionaryRef>(CFDictionaryGetValue(meta, CFSTR("Filter"))))
                if (CFArrayRef bundles = reinterpret_cast<CFArrayRef>(CFDictionaryGetValue(filter, CFSTR("Bundles"))))
                    for (CFIndex i(0), count(CFArrayGetCount(bundles)); i != count; ++i) {
                        CFStringRef bundle(reinterpret_cast<CFStringRef>(CFArrayGetValueAtIndex(bundles, i)));
                        if (CFBundleGetBundleWithIdentifier(bundle) != NULL) {
                            load = true;
                            break;
                        }
                    }

            CFRelease(meta);
        }

        if (!load)
            continue;

        memcpy(path + length - 5, "dylib", 5);
        CFLog(CFSTR("MS:Notice: Loading: %s"), path);

        void *handle(dlopen(path, RTLD_LAZY | RTLD_GLOBAL));
        if (handle == NULL) {
            CFLog(CFSTR("MS:Error: %s"), dlerror());
            continue;
        }
    }
}
