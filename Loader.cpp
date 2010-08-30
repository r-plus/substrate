/* Cydia Substrate - Powerful Code Insertion Platform
 * Copyright (C) 2008-2010  Jay Freeman (saurik)
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

#include <CoreFoundation/CoreFoundation.h>

#include <CoreFoundation/CFPriv.h>
#include <CoreFoundation/CFLogUtilities.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <dlfcn.h>
#include <unistd.h>

#include <objc/runtime.h>
#include "CydiaSubstrate.h"

#define ForSaurik 0

static char MSWatch[PATH_MAX];

static void MSAction(int sig, siginfo_t *info, void *uap) {
    open(MSWatch, O_CREAT | O_RDWR, 0644);
    raise(sig);
}

#define Libraries_ "/Library/MobileSubstrate/DynamicLibraries"
#define Safety_ "/Library/Frameworks/CydiaSubstrate.framework/MobileSafety.dylib"

extern "C" char ***_NSGetArgv(void);

MSInitialize {
#if 1
    CFBundleRef bundle(CFBundleGetMainBundle());
    CFStringRef identifier(bundle == NULL ? NULL : CFBundleGetIdentifier(bundle));
#else
    CFBundleRef bundle;
    CFStringRef identifier;

    if (
        dlopen("/usr/sbin/mediaserverd", RTLD_LAZY | RTLD_NOLOAD) != NULL ||
        dlopen("/System/Library/PrivateFrameworks/CoreTelephony.framework/Support/CommCenter", RTLD_LAZY | RTLD_NOLOAD) != NULL
    ) {
        bundle = NULL;
        identifier = NULL;
    } else if (dlopen(Foundation_f, RTLD_LAZY | RTLD_NOLOAD) == NULL)
        return;
    else {
        bundle = CFBundleGetMainBundle();
        identifier = bundle == NULL ? NULL : CFBundleGetIdentifier(bundle);
        if (identifier == NULL)
            return;
    }
#endif

    char *argv0(**_NSGetArgv());
    char *slash(strrchr(argv0, '/'));
    slash = slash == NULL ? argv0 : slash + 1;

    Class (*NSClassFromString)(CFStringRef) = reinterpret_cast<Class (*)(CFStringRef)>(dlsym(RTLD_DEFAULT, "NSClassFromString"));

    CFLog(kCFLogLevelNotice, CFSTR("MS:Notice: Installing: %@ [%s] (%.2f)"), identifier, slash, kCFCoreFoundationVersionNumber);

    const char *dat(NULL);
    if (identifier != NULL && CFEqual(identifier, CFSTR("com.apple.springboard")))
        dat = "com.saurik.mobilesubstrate.dat";
    if (identifier == NULL && strcmp(slash, "CommCenter") == 0)
        dat = "com.saurik.MobileSubstrate.CommCenter.dat";

    if (dat != NULL) {
        CFURLRef home(CFCopyHomeDirectoryURLForUser(NULL));
        CFURLGetFileSystemRepresentation(home, TRUE, reinterpret_cast<UInt8 *>(MSWatch), sizeof(MSWatch));
        CFRelease(home);
        strcat(MSWatch, "/Library/Preferences/");
        strcat(MSWatch, dat);

        if (access(MSWatch, R_OK) == 0) {
            if (unlink(MSWatch) == -1)
                CFLog(kCFLogLevelError, CFSTR("MS:Error: Cannot Clear: %s"), strerror(errno));

            void *handle(dlopen(Safety_, RTLD_LAZY | RTLD_GLOBAL));
            if (handle == NULL)
                CFLog(kCFLogLevelError, CFSTR("MS:Error: Cannot Load: %s"), dlerror());

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
                CFLog(kCFLogLevelWarning, CFSTR("MS:Error: Cannot Stack: %s"), strerror(errno));
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
        HookSignal(SIGSYS)
    }

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

        bool load = true;
        if (meta != NULL) {
            if (CFDictionaryRef filter = reinterpret_cast<CFDictionaryRef>(CFDictionaryGetValue(meta, CFSTR("Filter")))) {
                if (CFArrayRef version = reinterpret_cast<CFArrayRef>(CFDictionaryGetValue(filter, CFSTR("CoreFoundationVersion")))) {
                    load = false;

                    if (CFIndex count = CFArrayGetCount(version)) {
                        if (count > 2) {
                            CFLog(kCFLogLevelError, CFSTR("MS:Error: Invalid CoreFoundationVersion: %@"), version);
                            goto release;
                        }

                        CFNumberRef number;
                        double value;

                        number = reinterpret_cast<CFNumberRef>(CFArrayGetValueAtIndex(version, 0));
                        CFNumberGetValue(number, kCFNumberDoubleType, &value);
                        if (value > kCFCoreFoundationVersionNumber)
                            goto release;

                        if (count != 1) {
                            number = reinterpret_cast<CFNumberRef>(CFArrayGetValueAtIndex(version, 1));
                            CFNumberGetValue(number, kCFNumberDoubleType, &value);
                            if (value <= kCFCoreFoundationVersionNumber)
                                goto release;
                        }
                    }

                    load = true;
                }

                bool any;
                if (CFStringRef mode = reinterpret_cast<CFStringRef>(CFDictionaryGetValue(filter, CFSTR("Mode"))))
                    any = CFEqual(mode, CFSTR("Any"));
                else
                    any = false;

                if (any)
                    load = false;

                if (CFArrayRef executables = reinterpret_cast<CFArrayRef>(CFDictionaryGetValue(filter, CFSTR("Executables")))) {
                    if (!any)
                        load = false;

                    CFStringRef name(CFStringCreateWithCStringNoCopy(kCFAllocatorDefault, slash, kCFStringEncodingUTF8, kCFAllocatorNull));

                    for (CFIndex i(0), count(CFArrayGetCount(executables)); i != count; ++i) {
                        CFStringRef executable(reinterpret_cast<CFStringRef>(CFArrayGetValueAtIndex(executables, i)));
                        if (CFEqual(executable, name)) {
                            if (ForSaurik)
                                CFLog(kCFLogLevelNotice, CFSTR("MS:Notice: Found: %@"), name);
                            load = true;
                            break;
                        }
                    }

                    CFRelease(name);

                    if (!any && !load)
                        goto release;
                }

                if (CFArrayRef bundles = reinterpret_cast<CFArrayRef>(CFDictionaryGetValue(filter, CFSTR("Bundles")))) {
                    if (!any)
                        load = false;

                    for (CFIndex i(0), count(CFArrayGetCount(bundles)); i != count; ++i) {
                        CFStringRef bundle(reinterpret_cast<CFStringRef>(CFArrayGetValueAtIndex(bundles, i)));
                        if (CFBundleGetBundleWithIdentifier(bundle) != NULL) {
                            if (ForSaurik)
                                CFLog(kCFLogLevelNotice, CFSTR("MS:Notice: Found: %@"), bundle);
                            load = true;
                            break;
                        }
                    }

                    if (!any && !load)
                        goto release;
                }

                if (CFArrayRef classes = reinterpret_cast<CFArrayRef>(CFDictionaryGetValue(filter, CFSTR("Classes")))) {
                    if (!any)
                        load = false;

                    if (NSClassFromString != NULL)
                        for (CFIndex i(0), count(CFArrayGetCount(classes)); i != count; ++i) {
                            CFStringRef _class(reinterpret_cast<CFStringRef>(CFArrayGetValueAtIndex(classes, i)));
                            if (NSClassFromString(_class) != NULL) {
                                if (ForSaurik)
                                    CFLog(kCFLogLevelNotice, CFSTR("MS:Notice: Found: %@"), _class);
                                load = true;
                                break;
                            }
                        }

                    if (!any && !load)
                        goto release;
                }
            }

          release:
            CFRelease(meta);
        }

        if (!load)
            continue;

        memcpy(path + length - 5, "dylib", 5);
        CFLog(kCFLogLevelNotice, CFSTR("MS:Notice: Loading: %s"), path);

        if (MSWatch[0] != '\0') {
            int fd(open(MSWatch, O_CREAT | O_RDWR, 0644));
            if (fd == -1)
                CFLog(kCFLogLevelError, CFSTR("MS:Error: Cannot Set: %s"), strerror(errno));
            else if (close(fd) == -1)
                CFLog(kCFLogLevelError, CFSTR("MS:Error: Cannot Close: %s"), strerror(errno));
        }

        void *handle(dlopen(path, RTLD_LAZY | RTLD_GLOBAL));

        if (MSWatch[0] != '\0')
            if (unlink(MSWatch) == -1)
                CFLog(kCFLogLevelError, CFSTR("MS:Error: Cannot Reset: %s"), strerror(errno));

        if (handle == NULL) {
            CFLog(kCFLogLevelError, CFSTR("MS:Error: %s"), dlerror());
            continue;
        }
    }

    if (false) {
        CFLog(kCFLogLevelNotice, CFSTR("MobileSubstrate fell asleep... I'll wake him up in 10 seconds ;P"));
        sleep(10);
    }
}
