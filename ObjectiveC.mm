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

#include "CydiaSubstrate.h"

#import <Foundation/Foundation.h>

// XXX: this is required by some code below
#ifdef __arm__
#include STRUCT_HPP
#include "ARM.hpp"
#endif

#include <objc/runtime.h>

#include <sys/mman.h>
#include <unistd.h>

#include "Debug.hpp"

extern "C" void *NSPushAutoreleasePool(unsigned);
extern "C" void NSPopAutoreleasePool(void *);

static void MSHookMessageInternal(Class _class, SEL sel, IMP imp, IMP *result, const char *prefix) {
    if (MSDebug)
        fprintf(stderr, "MSHookMessageInternal(%s, %s, %p, %p, \"%s\")\n",
            _class == nil ? "nil" : class_getName(_class),
            sel == NULL ? "NULL" : sel_getName(sel),
            imp, result, prefix
        );
    if (_class == nil) {
        fprintf(stderr, "MS:Warning: nil class argument\n");
        return;
    } else if (sel == nil) {
        fprintf(stderr, "MS:Warning: nil sel argument\n");
        return;
    } else if (imp == nil) {
        fprintf(stderr, "MS:Warning: nil imp argument\n");
        return;
    }

    const char *name(sel_getName(sel));

    Method method(class_getInstanceMethod(_class, sel));
    if (method == nil) {
        fprintf(stderr, "MS:Warning: message not found [%s %s]\n", class_getName(_class), name);
        return;
    }

    const char *type(method_getTypeEncoding(method));

    bool direct(false);

    unsigned count;
    Method *methods(class_copyMethodList(_class, &count));
    for (unsigned i(0); i != count; ++i)
        if (methods[i] == method) {
            direct = true;
            break;
        }
    free(methods);

    IMP old(NULL);

// XXX: port this to x86
#if defined(__arm__)
    if (!direct) {
        size_t length(13 * sizeof(uint32_t));

        uint32_t *buffer(reinterpret_cast<uint32_t *>(mmap(
            NULL, length, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0
        )));

        if (buffer == MAP_FAILED)
            fprintf(stderr, "MS:Error:mmap() = %d\n", errno);
        else if (false) fail:
            munmap(buffer, length);
        else {
            bool stret;
            // XXX: you can't return an array in C, but really... check for '['?!
            // http://www.opensource.apple.com/source/gcc3/gcc3-1175/libobjc/sendmsg.c
            if (*type != '[' && *type != '(' && *type != '{')
                stret = false;
            else {
                void *pool(NSPushAutoreleasePool(0));
                NSMethodSignature *signature([NSMethodSignature signatureWithObjCTypes:type]);
                NSUInteger rlength([signature methodReturnLength]);
                stret = rlength > OBJC_MAX_STRUCT_BY_VALUE || struct_forward_array[rlength];
                NSPopAutoreleasePool(pool);
            }

            A$r rs(stret ? A$r1 : A$r0);
            A$r rc(stret ? A$r2 : A$r1);
            A$r re(stret ? A$r0 : A$r2);

            buffer[ 0] = A$stmdb_sp$_$rs$((1 << rs) | (1 << re) | (1 << A$r3) | (1 << A$lr));
            buffer[ 1] = A$ldr_rd_$rn_im$(A$r0, A$pc, (10 - 1 - 2) * 4);
            buffer[ 2] = A$ldr_rd_$rn_im$(A$r1, A$pc, (11 - 2 - 2) * 4);
            buffer[ 3] = A$ldr_rd_$rn_im$(A$lr, A$pc, (12 - 3 - 2) * 4);
            buffer[ 4] = A$blx_rm(A$lr);
            // XXX: if you store this value to the stack now you can avoid instruction 7 later
            buffer[ 5] = A$mov_rd_rm(rc, A$r0);
            buffer[ 6] = A$ldmia_sp$_$rs$((1 << rs) | (1 << re) | (1 << A$r3) | (1 << A$lr));
            buffer[ 7] = A$str_rd_$rn_im$(rc, A$sp, -4);
            buffer[ 8] = A$ldr_rd_$rn_im$(rc, A$pc, (11 - 8 - 2) * 4);
            buffer[ 9] = A$ldr_rd_$rn_im$(A$pc, A$sp, -4);
            buffer[10] = reinterpret_cast<uint32_t>(class_getSuperclass(_class));
            buffer[11] = reinterpret_cast<uint32_t>(sel);
            buffer[12] = reinterpret_cast<uint32_t>(stret ? &class_getMethodImplementation_stret : &class_getMethodImplementation);

            if (mprotect(buffer, length, PROT_READ | PROT_EXEC) == -1) {
                fprintf(stderr, "MS:Error:mprotect():%d\n", errno);
                goto fail;
            }

            old = reinterpret_cast<IMP>(buffer);

            if (MSDebug) {
                char name[16];
                sprintf(name, "%p", old);
                MSLogHex(buffer, length, name);
            }
        }
    }
#endif

    if (old == NULL)
        old = method_getImplementation(method);

    if (result != NULL)
        *result = old;

    if (prefix != NULL) {
        size_t namelen(strlen(name));
        size_t fixlen(strlen(prefix));

        char *newname(reinterpret_cast<char *>(alloca(fixlen + namelen + 1)));
        memcpy(newname, prefix, fixlen);
        memcpy(newname + fixlen, name, namelen + 1);

        if (!class_addMethod(_class, sel_registerName(newname), old, type))
            fprintf(stderr, "MS:Error: failed to rename [%s %s]\n", class_getName(_class), name);
    }

    if (direct)
        method_setImplementation(method, imp);
    else
        class_addMethod(_class, sel, imp, type);
}

_extern void MSHookMessageEx(Class _class, SEL sel, IMP imp, IMP *result) {
    MSHookMessageInternal(_class, sel, imp, result, NULL);
}

#ifdef __arm__
_extern IMP MSHookMessage(Class _class, SEL sel, IMP imp, const char *prefix) {
    IMP result(NULL);
    MSHookMessageInternal(_class, sel, imp, &result, prefix);
    return result;
}
#endif

#ifdef __arm__
_extern void _Z13MSHookMessageP10objc_classP13objc_selectorPFP11objc_objectS4_S2_zEPKc(Class _class, SEL sel, IMP imp, const char *prefix) {
    MSHookMessageInternal(_class, sel, imp, NULL, prefix);
}
#endif
