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

#include <unistd.h>

#ifdef __arm__
/* WebCore (ARM) PC-Relative:
X    1  ldr r*,[pc,r*] !=
     2 fldd d*,[pc,#*]
X    5  str r*,[pc,r*] !=
     8 flds s*,[pc,#*]
   400  ldr r*,[pc,r*] ==
   515  add r*, pc,r*  ==
X 4790  ldr r*,[pc,#*]    */

// x=0; while IFS= read -r line; do if [[ ${#line} -ne 0 && $line == +([^\;]): ]]; then x=2; elif [[ $line == ' +'* && $x -ne 0 ]]; then ((--x)); echo "$x${line}"; fi; done <WebCore.asm >WebCore.pc
// grep pc WebCore.pc | cut -c 40- | sed -Ee 's/^ldr *(ip|r[0-9]*),\[pc,\#0x[0-9a-f]*\].*/ ldr r*,[pc,#*]/;s/^add *r[0-9]*,pc,r[0-9]*.*/ add r*, pc,r*/;s/^(st|ld)r *r([0-9]*),\[pc,r([0-9]*)\].*/ \1r r\2,[pc,r\3]/;s/^fld(s|d) *(s|d)[0-9]*,\[pc,#0x[0-9a-f]*].*/fld\1 \2*,[pc,#*]/' | sort | uniq -c | sort -n

enum A$r {
    A$r0, A$r1, A$r2, A$r3,
    A$r4, A$r5, A$r6, A$r7,
    A$r8, A$r9, A$r10, A$r11,
    A$r12, A$r13, A$r14, A$r15,
    A$sp = A$r13,
    A$lr = A$r14,
    A$pc = A$r15
};

#define A$ldr_rd_$rn_im$(rd, rn, im) /* ldr rd, [rn, #im] */ \
    (0xe5100000 | ((im) < 0 ? 0 : 1 << 23) | ((rn) << 16) | ((rd) << 12) | abs(im))
#define A$stmia_sp$_$r0$  0xe8ad0001 /* stmia sp!, {r0}   */
#define A$bx_r0           0xe12fff10 /* bx r0             */

#define T$pop_$r0$ 0xbc01 // pop {r0}
#define T$bx_pc    0x4778 // bx pc
#define T$nop      0x46c0 // nop

extern "C" void __clear_cache (char *beg, char *end);

static inline bool A$pcrel$r(uint32_t ic) {
    return (ic & 0x0c000000) == 0x04000000 && (ic & 0xf0000000) != 0xf0000000 && (ic & 0x000f0000) == 0x000f0000;
}

static void MSHookFunctionThumb(void *symbol, void *replace, void **result) {
    if (symbol == NULL)
        return;

    int page = getpagesize();
    uintptr_t address = reinterpret_cast<uintptr_t>(symbol);
    uintptr_t base = address / page * page;

    if (page - (reinterpret_cast<uintptr_t>(symbol) - base) < 8)
        page *= 2;

    /* XXX: intelligent page doubling */

    mach_port_t self = mach_task_self();

    if (kern_return_t error = vm_protect(self, base, page, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY)) {
        fprintf(stderr, "MS:Error:vm_protect():%d\n", error);
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
    arm[0] = A$ldr_rd_$rn_im$(A$pc, A$pc, 4 - 8);
    arm[1] = reinterpret_cast<uint32_t>(replace);

    unsigned used(1 + align + 4);
    __clear_cache(reinterpret_cast<char *>(thumb), reinterpret_cast<char *>(thumb + used));

    if (kern_return_t error = vm_protect(self, base, page, FALSE, VM_PROT_READ | VM_PROT_EXECUTE))
        fprintf(stderr, "MS:Error:vm_protect():%d\n", error);

    if (true)
        fprintf(stderr, "MS:Error:MSHookFunctionThumb(, , !NULL)\n");
    else
    if (result != NULL) {
        size_t size(used);

        bool pad((used & 0x2) == 0);

        size += 1 + 2 * sizeof(uint32_t) / sizeof(uint16_t);
        size_t length(sizeof(uint16_t) * size);

        uint16_t *buffer = reinterpret_cast<uint16_t *>(mmap(
            NULL, length, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0
        ));

        if (buffer == MAP_FAILED) {
            fprintf(stderr, "MS:Error:mmap():%d\n", errno);
            return;
        }

        size_t start(0);//, end(size);
        for (unsigned offset(0); offset != used; ++offset)
            // XXX: Thumb pc-relative reassembler
            buffer[start++] = backup[offset];

        buffer[start++] = T$bx_pc;
        if (pad)
            buffer[start++] = T$nop;

        uint32_t *transfer = reinterpret_cast<uint32_t *>(buffer + start);
        transfer[0] = A$ldr_rd_$rn_im$(A$r0, A$pc, 4 - 8);
        transfer[1] = reinterpret_cast<uint32_t>(thumb + used) + 1;

        if (mprotect(buffer, length, PROT_READ | PROT_EXEC) == -1) {
            fprintf(stderr, "MS:Error:mprotect():%d\n", errno);
            return;
        }

        *result = reinterpret_cast<uint8_t *>(buffer) + 1;
    }
}

static void MSHookFunctionARM(void *symbol, void *replace, void **result) {
    if (symbol == NULL)
        return;

    int page = getpagesize();
    uintptr_t address = reinterpret_cast<uintptr_t>(symbol);
    uintptr_t base = address / page * page;

    if (page - (reinterpret_cast<uintptr_t>(symbol) - base) < 8)
        page *= 2;

    mach_port_t self = mach_task_self();

    if (kern_return_t error = vm_protect(self, base, page, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY)) {
        fprintf(stderr, "MS:Error:vm_protect():%d\n", error);
        return;
    }

    uint32_t *code = reinterpret_cast<uint32_t *>(symbol);
    uint32_t backup[2] = {code[0], code[1]};

    code[0] = A$ldr_rd_$rn_im$(A$pc, A$pc, 4 - 8);
    code[1] = reinterpret_cast<uint32_t>(replace);

    size_t used(2);
    __clear_cache(reinterpret_cast<char *>(code), reinterpret_cast<char *>(code + used));

    if (kern_return_t error = vm_protect(self, base, page, FALSE, VM_PROT_READ | VM_PROT_EXECUTE))
        fprintf(stderr, "MS:Error:vm_protect():%d\n", error);

    if (result != NULL)
        if (backup[0] == A$ldr_rd_$rn_im$(A$pc, A$pc, 4 - 8))
            *result = reinterpret_cast<void *>(backup[1]);
        else {
            size_t size(0);
            for (unsigned offset(0); offset != used; ++offset)
                if (A$pcrel$r(backup[offset]))
                    size += 3;
                else
                    size += 1;

            size += 2;
            size_t length(sizeof(uint32_t) * size);

            uint32_t *buffer = reinterpret_cast<uint32_t *>(mmap(
                NULL, length, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0
            ));

            if (buffer == MAP_FAILED) {
                fprintf(stderr, "MS:Error:mmap():%d\n", errno);
                *result = NULL;
                return;
            }

            if (false) fail: {
                munmap(buffer, length);
                *result = NULL;
                return;
            }

            size_t start(0), end(size);
            for (unsigned offset(0); offset != used; ++offset)
                if (A$pcrel$r(backup[offset])) {
                    union {
                        uint32_t value;

                        struct {
                            uint32_t rm : 4;
                            uint32_t : 1;
                            uint32_t shift : 2;
                            uint32_t shiftamount : 5;
                            uint32_t rd : 4;
                            uint32_t rn : 4;
                            uint32_t l : 1;
                            uint32_t w : 1;
                            uint32_t b : 1;
                            uint32_t u : 1;
                            uint32_t p : 1;
                            uint32_t mode : 1;
                            uint32_t type : 2;
                            uint32_t cond : 4;
                        };
                    } bits = {backup[offset]};

                    if (bits.mode != 0 && bits.rd == bits.rm) {
                        fprintf(stderr, "MS:Error:pcrel(%u):%s (rd == rm)\n", offset, bits.l == 0 ? "str" : "ldr");
                        goto fail;
                    } else {
                        buffer[start+0] = A$ldr_rd_$rn_im$(bits.rd, A$pc, (end - 1 - start) * 4 - 8);
                        buffer[end-1] = reinterpret_cast<uint32_t>(code + offset) + 8;

                        start += 1;
                        end -= 1;
                    }

                    bits.rn = bits.rd;
                    buffer[start++] = bits.value;
                } else
                    buffer[start++] = backup[offset];

            buffer[start+0] = A$ldr_rd_$rn_im$(A$pc, A$pc, 4 - 8);
            buffer[start+1] = reinterpret_cast<uint32_t>(code + used);

            if (mprotect(buffer, length, PROT_READ | PROT_EXEC) == -1) {
                fprintf(stderr, "MS:Error:mprotect():%d\n", errno);
                goto fail;
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
#endif

#ifdef __i386__
extern "C" void MSHookFunction(void *symbol, void *replace, void **result) {
    fprintf(stderr, "MS:Error:x86\n");
}
#endif

extern "C" IMP MSHookMessage(Class _class, SEL sel, IMP imp, const char *prefix) {
    if (_class == nil)
        return NULL;

    Method method = class_getInstanceMethod(_class, sel);
    if (method == nil)
        return NULL;

    const char *name = sel_getName(sel);
    const char *type = method_getTypeEncoding(method);

    IMP old = method_getImplementation(method);

    if (prefix != NULL) {
        size_t namelen = strlen(name);
        size_t fixlen = strlen(prefix);

        char *newname = reinterpret_cast<char *>(alloca(fixlen + namelen + 1));
        memcpy(newname, prefix, fixlen);
        memcpy(newname + fixlen, name, namelen + 1);

        if (!class_addMethod(_class, sel_registerName(newname), old, type))
            fprintf(stderr, "MS:Error: failed to rename [%s %s]\n", class_getName(_class), name);
    }

    unsigned int count;
    Method *methods = class_copyMethodList(_class, &count);
    for (unsigned int index(0); index != count; ++index)
        if (methods[index] == method)
            goto found;

    if (imp != NULL)
        if (!class_addMethod(_class, sel, imp, type))
            fprintf(stderr, "MS:Error: failed to rename [%s %s]\n", class_getName(_class), name);
    goto done;

  found:
    if (imp != NULL)
        method_setImplementation(method, imp);

  done:
    free(methods);
    return old;
}

#if defined(__APPLE__) && defined(__arm__)
extern "C" void _Z13MSHookMessageP10objc_classP13objc_selectorPFP11objc_objectS4_S2_zEPKc(Class _class, SEL sel, IMP imp, const char *prefix) {
    MSHookMessage(_class, sel, imp, prefix);
}

extern "C" void _Z14MSHookFunctionPvS_PS_(void *symbol, void *replace, void **result) {
    return MSHookFunction(symbol, replace, result);
}
#endif
