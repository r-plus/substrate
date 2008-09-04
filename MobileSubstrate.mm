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

#import <Foundation/Foundation.h>

#include <mach/mach_init.h>
#include <mach/vm_map.h>

#include <objc/runtime.h>
#include <sys/mman.h>

#include <dlfcn.h>
#include <unistd.h>

// ldr pc, [pc, #-4]
#define A$ldr_pc_$pc_m4$ 0xe51ff004

#define T$bx_pc 0x4778
#define T$nop 0x46c0

extern "C" void __clear_cache (char *beg, char *end);

static void MSHookFunctionThumb(void *symbol, void *replace, void **result) {
    if (symbol == NULL)
        return;
    if (result != NULL)
        NSLog(@"MS:Error:MSHookFunctionThumb(, , !NULL)");

    int page = getpagesize();
    uintptr_t address = reinterpret_cast<uintptr_t>(symbol);
    uintptr_t base = address / page * page;

    mach_port_t self = mach_task_self();

    if (kern_return_t error = vm_protect(self, base, page, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY)) {
        NSLog(@"MS:Error:vm_protect():%d", error);
        return;
    }

    uint16_t *thumb = reinterpret_cast<uint16_t *>(symbol);

    uint16_t backup[6];
    memcpy(backup, thumb, sizeof(uint16_t) * 6);

    thumb[0] = T$bx_pc;

    unsigned align;
    if ((address & 0x2) != 0)
        align = 0;
    else {
        align = 1;
        thumb[1] = T$nop;
    }

    uint32_t *arm = reinterpret_cast<uint32_t *>(thumb + 1 + align);

    arm[0] = A$ldr_pc_$pc_m4$;
    arm[1] = reinterpret_cast<uint32_t>(replace);

    __clear_cache(reinterpret_cast<char *>(thumb), reinterpret_cast<char *>(thumb + 1 + align + 4));

    if (kern_return_t error = vm_protect(self, base, page, FALSE, VM_PROT_READ | VM_PROT_EXECUTE))
        NSLog(@"MS:Error:vm_protect():%d", error);

#if 0
    if (result != NULL) {
        uint32_t *buffer = reinterpret_cast<uint32_t *>(mmap(
            NULL, sizeof(uint32_t) * 5,
            PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE,
            -1, 0
        ));

        if (buffer == MAP_FAILED) {
            NSLog(@"WB:Error:mmap():%d", errno);
            return;
        }

        buffer[0] = A$bx_pc;
        buffer[0] = backup[0];
        buffer[1] = backup[1];
        buffer[3] = reinterpret_cast<uint32_t>(code + 2);

        if (mprotect(buffer, sizeof(uint32_t) * 5, PROT_READ | PROT_EXEC) == -1) {
            NSLog(@"MS:Error:mprotect():%d", errno);
            return;
        }

        *result = buffer;
    }
#endif
}

static void MSHookFunctionARM(void *symbol, void *replace, void **result) {
    if (symbol == NULL)
        return;

    int page = getpagesize();
    uintptr_t base = reinterpret_cast<uintptr_t>(symbol) / page * page;

    mach_port_t self = mach_task_self();

    if (kern_return_t error = vm_protect(self, base, page, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY)) {
        NSLog(@"MS:Error:vm_protect():%d", error);
        return;
    }

    uint32_t *code = reinterpret_cast<uint32_t *>(symbol);
    uint32_t backup[2] = {code[0], code[1]};

    code[0] = A$ldr_pc_$pc_m4$;
    code[1] = reinterpret_cast<uint32_t>(replace);

    __clear_cache(reinterpret_cast<char *>(code), reinterpret_cast<char *>(code + 2));

    if (kern_return_t error = vm_protect(self, base, page, FALSE, VM_PROT_READ | VM_PROT_EXECUTE))
        NSLog(@"MS:Error:vm_protect():%d", error);

    if (result != NULL) {
        uint32_t *buffer = reinterpret_cast<uint32_t *>(mmap(
            NULL, sizeof(uint32_t) * 4,
            PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE,
            -1, 0
        ));

        if (buffer == MAP_FAILED) {
            NSLog(@"WB:Error:mmap():%d", errno);
            return;
        }

        buffer[0] = backup[0];
        buffer[1] = backup[1];
        buffer[2] = A$ldr_pc_$pc_m4$;
        buffer[3] = reinterpret_cast<uint32_t>(code + 2);

        if (mprotect(buffer, sizeof(uint32_t) * 4, PROT_READ | PROT_EXEC) == -1) {
            NSLog(@"MS:Error:mprotect():%d", errno);
            return;
        }

        *result = buffer;
    }
}

extern "C" void MSHookFunction(void *symbol, void *replace, void **result) {
    if ((reinterpret_cast<uintptr_t>(symbol) & 0x1) == 0)
        return MSHookFunctionARM(symbol, replace, result);
    else
        return MSHookFunctionThumb(reinterpret_cast<void *>(reinterpret_cast<uintptr_t>(symbol) & ~0x1), replace, result);
}

extern "C" void MSHookMessage(Class _class, SEL sel, IMP imp, const char *prefix) {
    if (_class == nil)
        return;

    Method method = class_getInstanceMethod(_class, sel);
    if (method == nil)
        return;

    const char *name = sel_getName(sel);
    size_t namelen = strlen(name);

    size_t fixlen = strlen(prefix);

    char newname[fixlen + namelen + 1];
    memcpy(newname, prefix, fixlen);
    memcpy(newname + fixlen, name, namelen + 1);

    const char *type = method_getTypeEncoding(method);
    if (!class_addMethod(_class, sel_registerName(newname), method_getImplementation(method), type))
        NSLog(@"WB:Error: failed to rename [%s %s]", class_getName(_class), name);

    unsigned int count;
    Method *methods = class_copyMethodList(_class, &count);
    for (unsigned int index(0); index != count; ++index)
        if (methods[index] == method)
            goto found;

    if (imp != NULL)
        if (!class_addMethod(_class, sel, imp, type))
            NSLog(@"WB:Error: failed to rename [%s %s]", class_getName(_class), name);
    goto done;

  found:
    if (imp != NULL)
        method_setImplementation(method, imp);

  done:
    free(methods);
}

extern "C" void _Z13MSHookMessageP10objc_classP13objc_selectorPFP11objc_objectS4_S2_zEPKc(Class _class, SEL sel, IMP imp, const char *prefix) {
    return MSHookMessage(_class, sel, imp, prefix);
}

extern "C" void _Z14MSHookFunctionPvS_PS_(void *symbol, void *replace, void **result) {
    return MSHookFunction(symbol, replace, result);
}

#define Path_ @"/Library/MobileSubstrate/DynamicLibraries"

extern "C" void MSInitialize() {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSLog(@"MS:Notice: Installing MobileSubstrate...");

    NSFileManager *manager = [NSFileManager defaultManager];
    for (NSString *dylib in [manager contentsOfDirectoryAtPath:Path_ error:NULL])
        if ([dylib hasSuffix:@".dylib"]) {
            NSLog(@"MS:Notice: Loading %@", dylib);
            void *handle = dlopen([[NSString stringWithFormat:@"%@/%@", Path_, dylib] UTF8String], RTLD_LAZY | RTLD_GLOBAL);
            if (handle == NULL) {
                NSLog(@"MS:Error: %s", dlerror());
                continue;
            }
        }

    [pool release];
}
