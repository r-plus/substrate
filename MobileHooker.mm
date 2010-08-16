/* Cydia Substrate - Powerful Code Insertion Platform
 * Copyright (C) 2008-2010  Jay Freeman (saurik)
*/

/* GNU Lesser General Public License, Version 3 {{{ */
/*
 * Cycript is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * Cycript is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 * License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with Cycript.  If not, see <http://www.gnu.org/licenses/>.
**/
/* }}} */

#import <Foundation/Foundation.h>

// XXX: this is required by some code below
#ifdef __arm__
#include "Struct.hpp"
#endif

#include <mach/mach_init.h>
#include <mach/vm_map.h>

#include <objc/runtime.h>
#include <objc/message.h>

#include <sys/mman.h>
#include <unistd.h>

#include "CydiaSubstrate.h"

#define _trace() do { \
    fprintf(stderr, "_trace(%u)\n", __LINE__); \
} while (false)

#if defined(__i386__) || defined(__x86_64__)
#include "disasm.h"
#endif

#ifdef __APPLE__
#import <CoreFoundation/CFLogUtilities.h>
/* XXX: proper CFStringRef conversion */
#define lprintf(format, ...) \
    CFLog(kCFLogLevelNotice, CFSTR(format), ## __VA_ARGS__)
#else
#define lprintf(format, ...) do { \
    fprintf(stderr, format...); \
    fprintf(stderr, "\n"); \
} while (false)
#endif

bool MSDebug = false;

static char _MSHexChar(uint8_t value) {
    return value < 0x20 || value >= 0x80 ? '.' : value;
}

#define HexWidth_ 16
#define HexDepth_ 4

void MSLogHex(const void *vdata, size_t size, const char *mark = 0) {
    const uint8_t *data((const uint8_t *) vdata);

    size_t i(0), j;

    char d[256];
    size_t b(0);
    d[0] = '\0';

    while (i != size) {
        if (i % HexWidth_ == 0) {
            if (mark != NULL)
                b += sprintf(d + b, "[%s] ", mark);
            b += sprintf(d + b, "0x%.3zx:", i);
        }

        b += sprintf(d + b, " %.2x", data[i]);

        if ((i + 1) % HexDepth_ == 0)
            b += sprintf(d + b, " ");

        if (++i % HexWidth_ == 0) {
            b += sprintf(d + b, " ");
            for (j = i - HexWidth_; j != i; ++j)
                b += sprintf(d + b, "%c", _MSHexChar(data[j]));

            lprintf("%s", d);
            b = 0;
            d[0] = '\0';
        }
    }

    if (i % HexWidth_ != 0) {
        for (j = i % HexWidth_; j != HexWidth_; ++j)
            b += sprintf(d + b, "   ");
        for (j = 0; j != (HexWidth_ - i % HexWidth_ + HexDepth_ - 1) / HexDepth_; ++j)
            b += sprintf(d + b, " ");
        b += sprintf(d + b, " ");
        for (j = i / HexWidth_ * HexWidth_; j != i; ++j)
            b += sprintf(d + b, "%c", _MSHexChar(data[j]));

        lprintf("%s", d);
        b = 0;
        d[0] = '\0';
    }
}

#ifdef __APPLE__
struct MSMemoryHook {
    mach_port_t self_;
    uintptr_t base_;
    size_t width_;

    MSMemoryHook(mach_port_t self, uintptr_t base, size_t width) :
        self_(self),
        base_(base),
        width_(width)
    {
    }
};

void *MSOpenMemory(void *data, size_t size) {
    if (size == 0)
        return NULL;

    int page(getpagesize());

    mach_port_t self(mach_task_self());
    uintptr_t base(reinterpret_cast<uintptr_t>(data) / page * page);
    size_t width(((reinterpret_cast<uintptr_t>(data) + size - 1) / page + 1) * page - base);

    if (kern_return_t error = vm_protect(self, base, width, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY)) {
        fprintf(stderr, "MS:Error:vm_protect() = %d\n", error);
        return NULL;
    }

    return new MSMemoryHook(self, base, width);
}

void MSCloseMemory(void *handle) {
    MSMemoryHook *memory(reinterpret_cast<MSMemoryHook *>(handle));
    if (kern_return_t error = vm_protect(memory->self_, memory->base_, memory->width_, FALSE, VM_PROT_READ | VM_PROT_EXECUTE | VM_PROT_COPY))
        fprintf(stderr, "MS:Error:vm_protect() = %d\n", error);
    delete memory;
}

extern "C" void __clear_cache (char *beg, char *end);

void MSClearCache(void *data, size_t size) {
    __clear_cache(reinterpret_cast<char *>(data), reinterpret_cast<char *>(data) + size);
}
#endif

template <typename Type_>
static void MSWrite(uint8_t *&buffer, Type_ value) {
    *reinterpret_cast<Type_ *>(buffer) = value;
    buffer += sizeof(Type_);
}

static void MSWrite(uint8_t *&buffer, uint8_t *data, size_t size) {
    memcpy(buffer, data, size);
    buffer += size;
}

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

enum A$c {
    A$eq, A$ne, A$cs, A$cc,
    A$mi, A$pl, A$vs, A$vc,
    A$hi, A$ls, A$ge, A$lt,
    A$gt, A$le, A$al,
    A$hs = A$cs,
    A$lo = A$cc
};

#define A$mrs_rm_cpsr(rd) /* mrs rd, cpsr */ \
    (0xe10f0000 | ((rd) << 12))
#define A$msr_cpsr_f_rm(rm) /* msr cpsr_f, rm */ \
    (0xe128f000 | (rm))
#define A$ldr_rd_$rn_im$(rd, rn, im) /* ldr rd, [rn, #im] */ \
    (0xe5100000 | ((im) < 0 ? 0 : 1 << 23) | ((rn) << 16) | ((rd) << 12) | abs(im))
#define A$str_rd_$rn_im$(rd, rn, im) /* sr rd, [rn, #im] */ \
    (0xe5000000 | ((im) < 0 ? 0 : 1 << 23) | ((rn) << 16) | ((rd) << 12) | abs(im))
#define A$sub_rd_rn_$im(rd, rn, im) /* sub, rd, rn, #im */ \
    (0xe2400000 | ((rn) << 16) | ((rd) << 12) | (im & 0xff))
#define A$blx_rm(rm) /* blx rm */ \
    (0xe12fff30 | (rm))
#define A$mov_rd_rm(rd, rm) /* mov rd, rm */ \
    (0xe1a00000 | ((rd) << 12) | (rm))
#define A$ldmia_sp$_$rs$(rs) /* ldmia sp!, {rs} */ \
    (0xe8b00000 | (A$sp << 16) | (rs))
#define A$stmdb_sp$_$rs$(rs) /* stmdb sp!, {rs} */ \
    (0xe9200000 | (A$sp << 16) | (rs))
#define A$stmia_sp$_$r0$  0xe8ad0001 /* stmia sp!, {r0}   */
#define A$bx_r0           0xe12fff10 /* bx r0             */

#define T$pop_$r0$ 0xbc01 // pop {r0}
#define T$b(im) /* b im */ \
    (0xde00 | (im & 0xff))
#define T$blx(rm) /* blx rm */ \
    (0x4780 | (rm << 3))
#define T$bx(rm) /* bx rm */ \
    (0x4700 | (rm << 3))
#define T$nop /* nop */ \
    (0x46c0)

#define T$add_rd_rm(rd, rm) /* add rd, rm */ \
    (0x4400 | (((rd) & 0x8) >> 3 << 7) | (((rm) & 0x8) >> 3 << 6) | (((rm) & 0x7) << 3) | ((rd) & 0x7))
#define T$push_r(r) /* push r... */ \
    (0xb400 | (((r) & (1 << A$lr)) >> A$lr << 8) | ((r) & 0xff))
#define T$pop_r(r) /* pop r... */ \
    (0xbc00 | (((r) & (1 << A$pc)) >> A$pc << 8) | ((r) & 0xff))
#define T$mov_rd_rm(rd, rm) /* mov rd, rm */ \
    (0x4600 | (((rd) & 0x8) >> 3 << 7) | (((rm) & 0x8) >> 3 << 6) | (((rm) & 0x7) << 3) | ((rd) & 0x7))
#define T$ldr_rd_$rn_im_4$(rd, rn, im) /* ldr rd, [rn, #im * 4] */ \
    (0x6800 | (((im) & 0x1f) << 6) | ((rn) << 3) | (rd))
#define T$ldr_rd_$pc_im_4$(rd, im) /* ldr rd, [PC, #im * 4] */ \
    (0x4800 | ((rd) << 8) | ((im) & 0xff))
#define T$cmp_rn_$im(rn, im) /* cmp rn, #im */ \
    (0x2000 | ((rn) << 8) | ((im) & 0xff))
#define T$it$_cd(cd, ms) /* it<ms>, cd */ \
    (0xbf00 | ((cd) << 4) | (ms))
#define T$cbz$_rn_$im(op,rn,im) /* cb<op>z rn, #im */ \
    (0xb100 | ((op) << 11) | (((im) & 0x40) >> 6 << 9) | (((im) & 0x3e) >> 1 << 3) | (rn))
#define T$b$_$im(cond,im) /* b<cond> #im */ \
    (cond == A$al ? 0xe000 | (((im) >> 1) & 0x7ff) : 0xd000 | ((cond) << 8) | (((im) >> 1) & 0xff))

#define T1$mrs_rd_apsr(rd) /* mrs rd, apsr */ \
    (0xf3ef)
#define T2$mrs_rd_apsr(rd) /* mrs rd, apsr */ \
    (0x8000 | ((rd) << 8))

#define T1$msr_apsr_nzcvqg_rn(rn) /* msr apsr, rn */ \
    (0xf380 | (rn))
#define T2$msr_apsr_nzcvqg_rn(rn) /* msr apsr, rn */ \
    (0x8c00)
#define T$msr_apsr_nzcvqg_rn(rn) /* msr apsr, rn */ \
    (T2$msr_apsr_nzcvqg_rn(rn) << 16 | T1$msr_apsr_nzcvqg_rn(rn))

static inline bool A$pcrel$r(uint32_t ic) {
    return (ic & 0x0c000000) == 0x04000000 && (ic & 0xf0000000) != 0xf0000000 && (ic & 0x000f0000) == 0x000f0000;
}

static inline bool T$32bit$i(uint16_t ic) {
    return ((ic & 0xe000) == 0xe000 && (ic & 0x1800) != 0x0000);
}

static inline bool T$pcrel$cbz(uint16_t ic) {
    return (ic & 0xf500) == 0xb100;
}

static inline bool T$pcrel$b(uint16_t ic) {
    return (ic & 0xf000) == 0xd000 && (ic & 0x0e00) != 0x0e00;
}

static inline bool T2$pcrel$b(uint16_t *ic) {
    return (ic[0] & 0xf800) == 0xf000 && ((ic[1] & 0xd000) == 0x9000 || (ic[1] & 0xd000) == 0x8000 && (ic[0] & 0x0380) != 0x0380);
}

static inline bool T$pcrel$bl(uint16_t *ic) {
    return (ic[0] & 0xf800) == 0xf000 && ((ic[1] & 0xd000) == 0xd000 || (ic[1] & 0xd001) == 0xc000);
}

static inline bool T$pcrel$ldr(uint16_t ic) {
    return (ic & 0xf800) == 0x4800;
}

static inline bool T$pcrel$add(uint16_t ic) {
    return (ic & 0xff78) == 0x4478;
}

static inline bool T$pcrel$ldrw(uint16_t ic) {
    return (ic & 0xff7f) == 0xf85f;
}

static size_t MSGetInstructionWidthThumb(void *start) {
    uint16_t *thumb(reinterpret_cast<uint16_t *>(start));
    return T$32bit$i(thumb[0]) ? 4 : 2;
}

static size_t MSGetInstructionWidthARM(void *start) {
    return 4;
}

static void MSHookFunctionThumb(void *symbol, void *replace, void **result) {
    if (symbol == NULL)
        return;

    // XXX: if the last instruction of this set is a 32-bit instruction, this does not work

    uint16_t *area(reinterpret_cast<uint16_t *>(symbol));

    unsigned align((reinterpret_cast<uintptr_t>(area) & 0x2) == 0 ? 0 : 1);
    uint16_t *thumb(area + align);

    uint32_t *arm(reinterpret_cast<uint32_t *>(thumb + 2));
    uint16_t *trail(reinterpret_cast<uint16_t *>(arm + 2));

    size_t required((trail - area) * sizeof(uint16_t));

    size_t used(0);
    while (used < required)
        used += MSGetInstructionWidthThumb(reinterpret_cast<uint8_t *>(area) + used);
    used = (used + sizeof(uint16_t) - 1) / sizeof(uint16_t) * sizeof(uint16_t);

    size_t blank((used - required) / sizeof(uint16_t));

    uint16_t backup[used / sizeof(uint16_t)];

    MSHookMemory code(area, used);

    if (
        (align == 0 || area[0] == T$nop) &&
        thumb[0] == T$bx(A$pc) &&
        thumb[1] == T$nop &&
        arm[0] == A$ldr_rd_$rn_im$(A$pc, A$pc, 4 - 8)
    ) {
        if (result != NULL) {
            *result = reinterpret_cast<void *>(arm[1]);
            result = NULL;
        }

        arm[1] = reinterpret_cast<uint32_t>(replace);

        MSClearCache(arm + 1, sizeof(uint32_t) * 1);
    } else {
        if (MSDebug) {
            char name[16];
            sprintf(name, "%p", area);
            MSLogHex(area, used + sizeof(uint16_t), name);
        }

        memcpy(backup, area, used);

        if (align != 0)
            area[0] = T$nop;

        thumb[0] = T$bx(A$pc);
        thumb[1] = T$nop;

        arm[0] = A$ldr_rd_$rn_im$(A$pc, A$pc, 4 - 8);
        arm[1] = reinterpret_cast<uint32_t>(replace);

        for (unsigned offset(0); offset != blank; ++offset)
            trail[offset] = T$nop;

        MSClearCache(area, used);
    }

    code.Close();

    if (MSDebug) {
        char name[16];
        sprintf(name, "%p", area);
        MSLogHex(area, used + sizeof(uint16_t), name);
    }

    // XXX: impedence mismatch
    used /= sizeof(uint16_t);

    if (result != NULL) {
        size_t size(used);
        for (unsigned offset(0); offset != used; ++offset)
            if (T$pcrel$ldr(backup[offset]))
                size += 3;
            else if (T$pcrel$b(backup[offset]))
                size += 6;
            else if (T2$pcrel$b(backup + offset)) {
                size += 5;
                ++offset;
            } else if (T$pcrel$bl(backup + offset)) {
                size += 5;
                ++offset;
            } else if (T$pcrel$cbz(backup[offset])) {
                size += 16;
            } else if (T$pcrel$ldrw(backup[offset])) {
                size += 2;
                ++offset;
            } else if (T$pcrel$add(backup[offset]))
                size += 6;
            else if (T$32bit$i(backup[offset]))
                ++offset;

        unsigned pad((size & 0x1) == 0 ? 0 : 1);
        size += pad + 2 + 2 * sizeof(uint32_t) / sizeof(uint16_t);
        size_t length(sizeof(uint16_t) * size);

        uint16_t *buffer(reinterpret_cast<uint16_t *>(mmap(
            NULL, length, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0
        )));

        if (buffer == MAP_FAILED) {
            fprintf(stderr, "MS:Error:mmap() = %d\n", errno);
            *result = NULL;
            return;
        }

        if (false) fail: {
            munmap(buffer, length);
            *result = NULL;
            return;
        }

        size_t start(pad), end(size);
        uint32_t *trailer(reinterpret_cast<uint32_t *>(buffer + end));
        for (unsigned offset(0); offset != used; ++offset) {
            if (T$pcrel$ldr(backup[offset])) {
                union {
                    uint16_t value;

                    struct {
                        uint16_t immediate : 8;
                        uint16_t rd : 3;
                        uint16_t : 5;
                    };
                } bits = {backup[offset+0]};

                buffer[start+0] = T$ldr_rd_$pc_im_4$(bits.rd, ((end-2 - (start+0)) * 2 - 4 + 2) / 4);
                buffer[start+1] = T$ldr_rd_$rn_im_4$(bits.rd, bits.rd, 0);
                *--trailer = ((reinterpret_cast<uint32_t>(area + offset) + 4) & ~0x2) + bits.immediate * 4;

                start += 2;
                end -= 2;
            } else if (T$pcrel$b(backup[offset])) {
                union {
                    uint16_t value;

                    struct {
                        uint16_t imm8 : 8;
                        uint16_t cond : 4;
                        uint16_t /*1101*/ : 4;
                    };
                } bits = {backup[offset+0]};

                intptr_t jump(bits.imm8 << 1);
                jump |= 1;
                jump <<= 23;
                jump >>= 23;

                buffer[start+0] = T$b$_$im(bits.cond, (end-6 - (start+0)) * 2 - 4);

                *--trailer = reinterpret_cast<uint32_t>(area + offset) + 4 + jump;
                *--trailer = A$ldr_rd_$rn_im$(A$pc, A$pc, 4 - 8);
                *--trailer = T$nop << 16 | T$bx(A$pc);

                start += 1;
                end -= 6;
            } else if (T2$pcrel$b(backup + offset)) {
                union {
                    uint16_t value;

                    struct {
                        uint16_t imm6 : 6;
                        uint16_t cond : 4;
                        uint16_t s : 1;
                        uint16_t : 5;
                    };
                } bits = {backup[offset+0]};

                union {
                    uint16_t value;

                    struct {
                        uint16_t imm11 : 11;
                        uint16_t j2 : 1;
                        uint16_t a : 1;
                        uint16_t j1 : 1;
                        uint16_t : 2;
                    };
                } exts = {backup[offset+1]};

                intptr_t jump(1);
                jump |= exts.imm11 << 1;
                jump |= bits.imm6 << 12;

                if (exts.a) {
                    jump |= bits.s << 24;
                    jump |= (~(bits.s ^ exts.j1) & 0x1) << 23;
                    jump |= (~(bits.s ^ exts.j2) & 0x1) << 22;
                    jump |= bits.cond << 18;
                    jump <<= 7;
                    jump >>= 7;
                } else {
                    jump |= bits.s << 20;
                    jump |= exts.j2 << 19;
                    jump |= exts.j1 << 18;
                    jump <<= 11;
                    jump >>= 11;
                }

                buffer[start+0] = T$b$_$im(exts.a ? A$al : bits.cond, (end-6 - (start+0)) * 2 - 4);

                *--trailer = reinterpret_cast<uint32_t>(area + offset) + 4 + jump;
                *--trailer = A$ldr_rd_$rn_im$(A$pc, A$pc, 4 - 8);
                *--trailer = T$nop << 16 | T$bx(A$pc);

                ++offset;
                start += 1;
                end -= 6;
            } else if (T$pcrel$bl(backup + offset)) {
                union {
                    uint16_t value;

                    struct {
                        uint16_t immediate : 10;
                        uint16_t s : 1;
                        uint16_t : 5;
                    };
                } bits = {backup[offset+0]};

                union {
                    uint16_t value;

                    struct {
                        uint16_t immediate : 11;
                        uint16_t j2 : 1;
                        uint16_t x : 1;
                        uint16_t j1 : 1;
                        uint16_t : 2;
                    };
                } exts = {backup[offset+1]};

                intptr_t jump(0);
                jump |= bits.s << 24;
                jump |= (~(bits.s ^ exts.j1) & 0x1) << 23;
                jump |= (~(bits.s ^ exts.j2) & 0x1) << 22;
                jump |= bits.immediate << 12;
                jump |= exts.immediate << 1;
                jump |= exts.x;
                jump <<= 7;
                jump >>= 7;

                buffer[start+0] = T$push_r(1 << A$r7);
                buffer[start+1] = T$ldr_rd_$pc_im_4$(A$r7, ((end-2 - (start+1)) * 2 - 4 + 2) / 4);
                buffer[start+2] = T$mov_rd_rm(A$lr, A$r7);
                buffer[start+3] = T$pop_r(1 << A$r7);
                buffer[start+4] = T$blx(A$lr);

                *--trailer = reinterpret_cast<uint32_t>(area + offset) + 4 + jump;

                ++offset;
                start += 5;
                end -= 2;
            } else if (T$pcrel$cbz(backup[offset])) {
                union {
                    uint16_t value;

                    struct {
                        uint16_t rn : 3;
                        uint16_t immediate : 5;
                        uint16_t : 1;
                        uint16_t i : 1;
                        uint16_t : 1;
                        uint16_t op : 1;
                        uint16_t : 4;
                    };
                } bits = {backup[offset+0]};

                intptr_t jump(1);
                jump |= bits.i << 6;
                jump |= bits.immediate << 1;

                //jump <<= 24;
                //jump >>= 24;

                unsigned rn(bits.rn);
                unsigned rt(rn == A$r7 ? A$r6 : A$r7);

                buffer[start+0] = T$push_r(1 << rt);
                buffer[start+1] = T1$mrs_rd_apsr(rt);
                buffer[start+2] = T2$mrs_rd_apsr(rt);
                buffer[start+3] = T$cbz$_rn_$im(bits.op, rn, (end-10 - (start+3)) * 2 - 4);
                buffer[start+4] = T1$msr_apsr_nzcvqg_rn(rt);
                buffer[start+5] = T2$msr_apsr_nzcvqg_rn(rt);
                buffer[start+6] = T$pop_r(1 << rt);

                *--trailer = reinterpret_cast<uint32_t>(area + offset) + 4 + jump;
                *--trailer = A$ldr_rd_$rn_im$(A$pc, A$pc, 4 - 8);
                *--trailer = T$nop << 16 | T$bx(A$pc);
                *--trailer = T$nop << 16 | T$pop_r(1 << rt);
                *--trailer = T$msr_apsr_nzcvqg_rn(rt);

#if 0
                if ((start & 0x1) == 0)
                    buffer[start++] = T$nop;
                buffer[start++] = T$bx(A$pc);
                buffer[start++] = T$nop;

                uint32_t *arm(reinterpret_cast<uint32_t *>(buffer + start));
                arm[0] = A$add(A$lr, A$pc, 1);
                arm[1] = A$ldr_rd_$rn_im$(A$pc, A$pc, (trailer - arm) * sizeof(uint32_t) - 8);
#endif

                start += 7;
                end -= 10;
            } else if (T$pcrel$ldrw(backup[offset])) {
                union {
                    uint16_t value;

                    struct {
                        uint16_t : 7;
                        uint16_t u : 1;
                        uint16_t : 8;
                    };
                } bits = {backup[offset+0]};

                union {
                    uint16_t value;

                    struct {
                        uint16_t immediate : 12;
                        uint16_t rd : 4;
                    };
                } exts = {backup[offset+1]};

                buffer[start+0] = T$ldr_rd_$pc_im_4$(exts.rd, ((end-2 - (start+0)) * 2 - 4 + 2) / 4);
                buffer[start+1] = T$ldr_rd_$rn_im_4$(exts.rd, exts.rd, 0);
                *--trailer = ((reinterpret_cast<uint32_t>(area + offset) + 4) & ~0x2) + (bits.u == 0 ? -exts.immediate : exts.immediate);

                ++offset;
                start += 2;
                end -= 2;
            } else if (T$pcrel$add(backup[offset])) {
                union {
                    uint16_t value;

                    struct {
                        uint16_t rd : 3;
                        uint16_t rm : 3;
                        uint16_t h2 : 1;
                        uint16_t h1 : 1;
                        uint16_t : 8;
                    };
                } bits = {backup[offset+0]};

                if (bits.h1) {
                    fprintf(stderr, "MS:Error:pcrel(%u):add (rd > r7)\n", offset);
                    goto fail;
                }

                unsigned rt(bits.rd == A$r7 ? A$r6 : A$r7);

                buffer[start+0] = T$push_r(1 << rt);
                buffer[start+1] = T$mov_rd_rm(rt, (bits.h1 << 3) | bits.rd);
                buffer[start+2] = T$ldr_rd_$pc_im_4$(bits.rd, ((end-2 - (start+2)) * 2 - 4 + 2) / 4);
                buffer[start+3] = T$add_rd_rm((bits.h1 << 3) | bits.rd, rt);
                buffer[start+4] = T$pop_r(1 << rt);
                *--trailer = reinterpret_cast<uint32_t>(area + offset) + 4;

                start += 5;
                end -= 2;
            } else if (T$32bit$i(backup[offset])) {
                buffer[start++] = backup[offset];
                buffer[start++] = backup[++offset];
            } else {
                buffer[start++] = backup[offset];
            }
        }

        buffer[start++] = T$bx(A$pc);
        buffer[start++] = T$nop;

        uint32_t *transfer = reinterpret_cast<uint32_t *>(buffer + start);
        transfer[0] = A$ldr_rd_$rn_im$(A$pc, A$pc, 4 - 8);
        transfer[1] = reinterpret_cast<uint32_t>(area + used) + 1;

        if (mprotect(buffer, length, PROT_READ | PROT_EXEC) == -1) {
            fprintf(stderr, "MS:Error:mprotect():%d\n", errno);
            return;
        }

        *result = reinterpret_cast<uint8_t *>(buffer + pad) + 1;

        if (MSDebug) {
            char name[16];
            sprintf(name, "%p", *result);
            MSLogHex(buffer, length, name);
        }
    }
}

static void MSHookFunctionARM(void *symbol, void *replace, void **result) {
    if (symbol == NULL)
        return;

    uint32_t *area(reinterpret_cast<uint32_t *>(symbol));
    uint32_t *arm(area);

    const size_t used(2);

    uint32_t backup[used] = {arm[0], arm[1]};

    MSHookMemory code(symbol, 8);

    arm[0] = A$ldr_rd_$rn_im$(A$pc, A$pc, 4 - 8);
    arm[1] = reinterpret_cast<uint32_t>(replace);

    MSClearCache(area, sizeof(uint32_t) * used);

    code.Close();

    if (result == NULL)
        return;

    if (backup[0] == A$ldr_rd_$rn_im$(A$pc, A$pc, 4 - 8)) {
        *result = reinterpret_cast<void *>(backup[1]);
        return;
    }

    size_t size(used);
    for (unsigned offset(0); offset != used; ++offset)
        if (A$pcrel$r(backup[offset]))
            size += 2;

    size += 2;
    size_t length(sizeof(uint32_t) * size);

    uint32_t *buffer(reinterpret_cast<uint32_t *>(mmap(
        NULL, length, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0
    )));

    if (buffer == MAP_FAILED) {
        fprintf(stderr, "MS:Error:mmap() = %d\n", errno);
        *result = NULL;
        return;
    }

    if (false) fail: {
        munmap(buffer, length);
        *result = NULL;
        return;
    }

    size_t start(0), end(size);
    uint32_t *trailer(reinterpret_cast<uint32_t *>(buffer + end));
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
            } bits = {backup[offset+0]};

            if (bits.mode != 0 && bits.rd == bits.rm) {
                fprintf(stderr, "MS:Error:pcrel(%u):%s (rd == rm)\n", offset, bits.l == 0 ? "str" : "ldr");
                goto fail;
            } else {
                buffer[start+0] = A$ldr_rd_$rn_im$(bits.rd, A$pc, (end-1 - (start+0)) * 4 - 8);
                *--trailer = reinterpret_cast<uint32_t>(area + offset) + 8;

                start += 1;
                end -= 1;
            }

            bits.rn = bits.rd;
            buffer[start++] = bits.value;
        } else
            buffer[start++] = backup[offset];

    buffer[start+0] = A$ldr_rd_$rn_im$(A$pc, A$pc, 4 - 8);
    buffer[start+1] = reinterpret_cast<uint32_t>(area + used);

    if (mprotect(buffer, length, PROT_READ | PROT_EXEC) == -1) {
        fprintf(stderr, "MS:Error:mprotect():%d\n", errno);
        goto fail;
    }

    *result = buffer;
}

extern "C" void MSHookFunction(void *symbol, void *replace, void **result) {
    if (MSDebug)
        fprintf(stderr, "MSHookFunction(%p, %p, %p)\n", symbol, replace, result);
    if ((reinterpret_cast<uintptr_t>(symbol) & 0x1) == 0)
        return MSHookFunctionARM(symbol, replace, result);
    else
        return MSHookFunctionThumb(reinterpret_cast<void *>(reinterpret_cast<uintptr_t>(symbol) & ~0x1), replace, result);
}
#endif

#if defined(__i386__) || defined(__x86_64__)
static size_t MSGetInstructionWidthIntel(void *start) {
    return disasm(reinterpret_cast<uint8_t *>(start));
}

#ifdef __LP64__
static const bool ia32 = false;
#else
static const bool ia32 = true;
#endif

static bool MSIs32BitOffset(uintptr_t target, uintptr_t source) {
    intptr_t offset(target - source);
    return int32_t(offset) == offset;
}

static size_t MSSizeOfJump(bool blind, uintptr_t target, uintptr_t source = 0) {
    if (ia32 || !blind && MSIs32BitOffset(target, source + 5))
        return 5;
    else if (uint64_t(target) >> 32 == 0)
        return 6;
    else
        return 14;
}

static size_t MSSizeOfJump(uintptr_t target, uintptr_t source) {
    return MSSizeOfJump(false, target, source);
}

static size_t MSSizeOfJump(uintptr_t target) {
    return MSSizeOfJump(true, target);
}

static size_t MSSizeOfJump(void *target, void *source) {
    return MSSizeOfJump(reinterpret_cast<uintptr_t>(target), reinterpret_cast<uintptr_t>(source));
}

static size_t MSSizeOfJump(void *target) {
    return MSSizeOfJump(reinterpret_cast<uintptr_t>(target));
}

static void MSWriteJump(uint8_t *&current, uintptr_t target) {
    uintptr_t source(reinterpret_cast<uintptr_t>(current));

    if (ia32 || MSIs32BitOffset(target, source + 5)) {
        MSWrite<uint8_t>(current, 0xe9);
        MSWrite<uint32_t>(current, target - (source + 5));
    } else {
        MSWrite<uint8_t>(current, 0x68);
        MSWrite<uint32_t>(current, target);

        uint32_t high(uint64_t(target) >> 32);
        if (high != 0) {
            MSWrite<uint8_t>(current, 0xc7);
            MSWrite<uint8_t>(current, 0x44);
            MSWrite<uint8_t>(current, 0x24);
            MSWrite<uint8_t>(current, 0x04);
            MSWrite<uint32_t>(current, high);
        }

        MSWrite<uint8_t>(current, 0xc3);
    }

#if 0
    MSWrite<uint8_t>(current, 0xff);
    MSWrite<uint8_t>(current, 0x25);
    MSWrite<uint32_t>(current, 0x00000000);
    MSWrite<uintptr_t>(current, target);
#endif
}

static void MSWriteJump(uint8_t *&current, void *target) {
    return MSWriteJump(current, reinterpret_cast<uintptr_t>(target));
}

extern "C" void MSHookFunction(void *symbol, void *replace, void **result) {
    if (MSDebug)
        fprintf(stderr, "MSHookFunction(%p, %p, %p)\n", symbol, replace, result);
    if (symbol == NULL)
        return;

    uintptr_t source(reinterpret_cast<uintptr_t>(symbol));
    uintptr_t target(reinterpret_cast<uintptr_t>(replace));

    uint8_t *area(reinterpret_cast<uint8_t *>(symbol));

    size_t required(MSSizeOfJump(target, source));

    if (MSDebug) {
        char name[16];
        sprintf(name, "%p", area);
        MSLogHex(area, 32, name);
    }

    size_t used(0);
    while (used < required) {
        size_t width(MSGetInstructionWidthIntel(area + used));
        if (width == 0) {
            fprintf(stderr, "MS:Error:MSGetInstructionWidthIntel(%p) == 0", area + used);
            return;
        }

        used += width;
    }

    size_t blank(used - required);

    if (MSDebug) {
        char name[16];
        sprintf(name, "%p", area);
        MSLogHex(area, used + sizeof(uint16_t), name);
    }

    uint8_t backup[used];
    memcpy(backup, area, used);

    MSHookMemory code(area, used); {
        uint8_t *current(area);
        MSWriteJump(current, target);
        for (unsigned offset(0); offset != blank; ++offset)
            MSWrite<uint8_t>(current, 0x90);
        MSClearCache(area, used);
    } code.Close();

    if (MSDebug) {
        char name[16];
        sprintf(name, "%p", area);
        MSLogHex(area, used + sizeof(uint16_t), name);
    }

    if (result == NULL)
        return;

    if (backup[0] == 0xe9) {
        *result = reinterpret_cast<void *>(source + 5 + *reinterpret_cast<uint32_t *>(backup + 1));
        return;
    }

    if (!ia32 && backup[0] == 0xff && backup[1] == 0x25) {
        *result = *reinterpret_cast<void **>(source + 6 + *reinterpret_cast<uint32_t *>(backup + 2));
        return;
    }

    size_t length(used + MSSizeOfJump(source + used));

    for (size_t offset(0), width; offset != used; offset += width) {
        width = MSGetInstructionWidthIntel(backup + offset);
        //_assert(width != 0 && offset + width <= used);

        if (backup[offset] == 0xeb) {
            length -= 2;
            length += MSSizeOfJump(area + offset + 2 + *reinterpret_cast<int8_t *>(backup + offset + 1));
        } else if (backup[offset] == 0xe9) {
            length -= 5;
            length += MSSizeOfJump(area + offset + 5 + *reinterpret_cast<int32_t *>(backup + offset + 1));
        } else if (
            backup[offset] == 0xe3 ||
            (backup[offset] & 0xf0) == 0x70
        ) {
            length += 2;
            length += MSSizeOfJump(area + offset + 2 + *reinterpret_cast<int8_t *>(backup + offset + 1));
        }
    }

    uint8_t *buffer(reinterpret_cast<uint8_t *>(mmap(
        NULL, length, PROT_READ | PROT_WRITE, MAP_ANON | MAP_PRIVATE, -1, 0
    )));

    if (buffer == MAP_FAILED) {
        fprintf(stderr, "MS:Error:mmap() = %d\n", errno);
        *result = NULL;
        return;
    }

    if (false) fail: {
        munmap(buffer, length);
        *result = NULL;
        return;
    }

    {
        uint8_t *current(buffer);

        for (size_t offset(0), width; offset != used; offset += width) {
            width = MSGetInstructionWidthIntel(backup + offset);
            //_assert(width != 0 && offset + width <= used);

            if (backup[offset] == 0xeb)
                MSWriteJump(current, area + offset + 2 + *reinterpret_cast<int8_t *>(backup + offset + 1));
            else if (backup[offset] == 0xe9)
                MSWriteJump(current, area + offset + 5 + *reinterpret_cast<int32_t *>(backup + offset + 1));
            else if (
                backup[offset] == 0xe3 ||
                (backup[offset] & 0xf0) == 0x70
            ) {
                MSWrite<uint8_t>(current, backup[offset]);
                MSWrite<uint8_t>(current, 2);
                MSWrite<uint8_t>(current, 0xeb);
                void *destiny(area + offset + 2 + *reinterpret_cast<int8_t *>(backup + offset + 1));
                MSWrite<uint8_t>(current, MSSizeOfJump(destiny, current + 1));
                MSWriteJump(current, destiny);
            } else {
                MSWrite(current, backup + offset, width);
            }
        }

        MSWriteJump(current, area + used);
    }

    if (mprotect(buffer, length, PROT_READ | PROT_EXEC) == -1) {
        fprintf(stderr, "MS:Error:mprotect():%d\n", errno);
        goto fail;
    }

    *result = buffer;

    if (MSDebug) {
        char name[16];
        sprintf(name, "%p", *result);
        MSLogHex(buffer, length, name);
    }
}
#endif

#ifdef __APPLE__

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

extern "C" IMP MSHookMessage(Class _class, SEL sel, IMP imp, const char *prefix) {
    IMP result(NULL);
    MSHookMessageInternal(_class, sel, imp, &result, prefix);
    return result;
}

extern "C" void MSHookMessageEx(Class _class, SEL sel, IMP imp, IMP *result) {
    MSHookMessageInternal(_class, sel, imp, result, NULL);
}

#endif

#if defined(__APPLE__) && defined(__arm__)
extern "C" void _Z13MSHookMessageP10objc_classP13objc_selectorPFP11objc_objectS4_S2_zEPKc(Class _class, SEL sel, IMP imp, const char *prefix) {
    MSHookMessage(_class, sel, imp, prefix);
}

extern "C" void _Z14MSHookFunctionPvS_PS_(void *symbol, void *replace, void **result) {
    return MSHookFunction(symbol, replace, result);
}
#endif
