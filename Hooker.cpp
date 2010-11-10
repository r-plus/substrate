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

#include <sys/mman.h>

#include "CydiaSubstrate.h"

#define _trace() do { \
    fprintf(stderr, "_trace(%u)\n", __LINE__); \
} while (false)

#if defined(__i386__) || defined(__x86_64__)
#include "hde64.h"
#endif

#include "Debug.hpp"

extern "C" void __clear_cache (char *beg, char *end);

static _finline void MSClearCache(void *data, size_t size) {
#ifdef __arm__
    // removed in iOS 4.1, it turns out __clear_cache had always been a nop
    // XXX: we should probably do something here... right?... right?!
#else
    __clear_cache(reinterpret_cast<char *>(data), reinterpret_cast<char *>(data) + size);
#endif
}

template <typename Type_>
_disused static _finline void MSWrite(uint8_t *&buffer, Type_ value) {
    *reinterpret_cast<Type_ *>(buffer) = value;
    buffer += sizeof(Type_);
}

_disused static _finline void MSWrite(uint8_t *&buffer, uint8_t *data, size_t size) {
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

#include "ARM.hpp"

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

#define T1$ldr_rt_$pc_im$(rt, im) /* ldr rt, [PC, #im] */ \
    (0xf85f | (im < 0 ? 0 : 1))
#define T2$ldr_rt_$pc_im$(rt, im) /* ldr rt, [PC, #im] */ \
    (((rt) << 12) | abs(im))

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

extern "C" size_t MSGetInstructionWidth(void *start) {
    if ((reinterpret_cast<uintptr_t>(start) & 0x1) == 0)
        return MSGetInstructionWidthARM(start);
    else
        return MSGetInstructionWidthThumb(reinterpret_cast<void *>(reinterpret_cast<uintptr_t>(start) & ~0x1));
}

static void SubstrateHookFunctionThumb(SubstrateProcessRef process, void *symbol, void *replace, void **result) {
    if (symbol == NULL)
        return;

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

    SubstrateHookMemory code(process, area, used);

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

static void SubstrateHookFunctionARM(SubstrateProcessRef process, void *symbol, void *replace, void **result) {
    if (symbol == NULL)
        return;

    uint32_t *area(reinterpret_cast<uint32_t *>(symbol));
    uint32_t *arm(area);

    const size_t used(2);

    uint32_t backup[used] = {arm[0], arm[1]};

    SubstrateHookMemory code(process, symbol, 8);

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

static void SubstrateHookFunction(SubstrateProcessRef process, void *symbol, void *replace, void **result) {
    if (MSDebug)
        fprintf(stderr, "SubstrateHookFunction(%p, %p, %p, %p)\n", process, symbol, replace, result);
    if ((reinterpret_cast<uintptr_t>(symbol) & 0x1) == 0)
        return SubstrateHookFunctionARM(process, symbol, replace, result);
    else
        return SubstrateHookFunctionThumb(process, reinterpret_cast<void *>(reinterpret_cast<uintptr_t>(symbol) & ~0x1), replace, result);
}
#endif

#if defined(__i386__) || defined(__x86_64__)
static size_t MSGetInstructionWidthIntel(void *start) {
    hde64s decode;
    return hde64_disasm(start, &decode);
}

#ifdef __LP64__
static const bool ia32 = false;
#else
static const bool ia32 = true;
#endif

_disused static bool MSIs32BitOffset(uintptr_t target, uintptr_t source) {
    intptr_t offset(target - source);
    return int32_t(offset) == offset;
}

_disused static size_t MSSizeOfSkip() {
    return 5;
}

_disused static size_t MSSizeOfPushPointer(uintptr_t target) {
    return uint64_t(target) >> 32 == 0 ? 5 : 13;
}

_disused static size_t MSSizeOfPushPointer(void *target) {
    return MSSizeOfPushPointer(reinterpret_cast<uintptr_t>(target));
}

_disused static size_t MSSizeOfJump(bool blind, uintptr_t target, uintptr_t source = 0) {
    if (ia32 || !blind && MSIs32BitOffset(target, source + 5))
        return MSSizeOfSkip();
    else
        return MSSizeOfPushPointer(target) + 1;
}

_disused static size_t MSSizeOfJump(uintptr_t target, uintptr_t source) {
    return MSSizeOfJump(false, target, source);
}

_disused static size_t MSSizeOfJump(uintptr_t target) {
    return MSSizeOfJump(true, target);
}

_disused static size_t MSSizeOfJump(void *target, void *source) {
    return MSSizeOfJump(reinterpret_cast<uintptr_t>(target), reinterpret_cast<uintptr_t>(source));
}

_disused static size_t MSSizeOfJump(void *target) {
    return MSSizeOfJump(reinterpret_cast<uintptr_t>(target));
}

_disused static void MSWriteSkip(uint8_t *&current, ssize_t size) {
    MSWrite<uint8_t>(current, 0xe9);
    MSWrite<uint32_t>(current, size);
}

_disused static void MSPushPointer(uint8_t *&current, uintptr_t target) {
    MSWrite<uint8_t>(current, 0x68);
    MSWrite<uint32_t>(current, target);

    if (uint32_t high = uint64_t(target) >> 32) {
        MSWrite<uint8_t>(current, 0xc7);
        MSWrite<uint8_t>(current, 0x44);
        MSWrite<uint8_t>(current, 0x24);
        MSWrite<uint8_t>(current, 0x04);
        MSWrite<uint32_t>(current, high);
    }
}

_disused static void MSPushPointer(uint8_t *&current, void *target) {
    return MSPushPointer(current, reinterpret_cast<uintptr_t>(target));
}

_disused static void MSWriteJump(uint8_t *&current, uintptr_t target) {
    uintptr_t source(reinterpret_cast<uintptr_t>(current));

    if (ia32 || MSIs32BitOffset(target, source + 5))
        MSWriteSkip(current, target - (source + 5));
    else {
        MSPushPointer(current, target);
        MSWrite<uint8_t>(current, 0xc3);
    }
}

_disused static void MSWriteJump(uint8_t *&current, void *target) {
    return MSWriteJump(current, reinterpret_cast<uintptr_t>(target));
}

_disused static void MSWritePop(uint8_t *&current, uint8_t target) {
    if (target >> 3 != 0)
        MSWrite<uint8_t>(current, 0x40 | (target & 0x08) >> 3);
    MSWrite<uint8_t>(current, 0x58 | target & 0x07);
}

_disused static size_t MSSizeOfPop(uint8_t target) {
    return target >> 3 != 0 ? 2 : 1;
}

_disused static void MSWriteMove64(uint8_t *&current, uint8_t source, uint8_t target) {
    MSWrite<uint8_t>(current, 0x48 | (target & 0x08) >> 3 << 2 | (source & 0x08) >> 3);
    MSWrite<uint8_t>(current, 0x8b);
    MSWrite<uint8_t>(current, (target & 0x07) << 3 | source & 0x07);
}

_disused static size_t MSSizeOfMove64() {
    return 3;
}

enum I$r {
    I$rax, I$rcx, I$rdx, I$rbx,
    I$rsp, I$rbp, I$rsi, I$rdi,
    I$r8, I$r9, I$r10, I$r11,
    I$r12, I$r13, I$r14, I$r15,
};

static void SubstrateHookFunction(SubstrateProcessRef process, void *symbol, void *replace, void **result) {
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

    SubstrateHookMemory code(process, area, used); {
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
        hde64s decode;
        hde64_disasm(backup + offset, &decode);
        width = decode.len;
        //_assert(width != 0 && offset + width <= used);

#ifdef __LP64__
        if ((decode.modrm & 0xc7) == 0x05) {
            if (decode.opcode == 0x8b) {
                void *destiny(area + offset + width + int32_t(decode.disp.disp32));
                uint8_t reg(decode.rex_r << 3 | decode.modrm_reg);
                length -= decode.len;
                length += MSSizeOfPushPointer(destiny);
                length += MSSizeOfPop(reg);
                length += MSSizeOfMove64();
            } else {
                fprintf(stderr, "MS:Error: Unknown RIP-Relative (%.2x %.2x)\n", decode.opcode, decode.opcode2);
                continue;
            }
        } else
#endif

        if (backup[offset] == 0xe8) {
            int32_t relative(*reinterpret_cast<int32_t *>(backup + offset + 1));
            void *destiny(area + offset + decode.len + relative);

            if (relative == 0) {
                length -= decode.len;
                length += MSSizeOfPushPointer(destiny);
            } else {
                length += MSSizeOfSkip();
                length += MSSizeOfJump(destiny);
            }
        } else if (backup[offset] == 0xeb) {
            length -= decode.len;
            length += MSSizeOfJump(area + offset + decode.len + *reinterpret_cast<int8_t *>(backup + offset + 1));
        } else if (backup[offset] == 0xe9) {
            length -= decode.len;
            length += MSSizeOfJump(area + offset + decode.len + *reinterpret_cast<int32_t *>(backup + offset + 1));
        } else if (
            backup[offset] == 0xe3 ||
            (backup[offset] & 0xf0) == 0x70
            // XXX: opcode2 & 0xf0 is 0x80?
        ) {
            length += decode.len;
            length += MSSizeOfJump(area + offset + decode.len + *reinterpret_cast<int8_t *>(backup + offset + 1));
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
            hde64s decode;
            hde64_disasm(backup + offset, &decode);
            width = decode.len;
            //_assert(width != 0 && offset + width <= used);

#ifdef __LP64__
            if ((decode.modrm & 0xc7) == 0x05) {
                if (decode.opcode == 0x8b) {
                    void *destiny(area + offset + width + int32_t(decode.disp.disp32));
                    uint8_t reg(decode.rex_r << 3 | decode.modrm_reg);
                    MSPushPointer(current, destiny);
                    MSWritePop(current, reg);
                    MSWriteMove64(current, reg, reg);
                } else {
                    fprintf(stderr, "MS:Error: Unknown RIP-Relative (%.2x %.2x)\n", decode.opcode, decode.opcode2);
                    goto copy;
                }
            } else
#endif

            if (backup[offset] == 0xe8) {
                int32_t relative(*reinterpret_cast<int32_t *>(backup + offset + 1));
                if (relative == 0)
                    MSPushPointer(current, area + offset + decode.len);
                else {
                    MSWrite<uint8_t>(current, 0xe8);
                    MSWrite<int32_t>(current, MSSizeOfSkip());
                    void *destiny(area + offset + decode.len + relative);
                    MSWriteSkip(current, MSSizeOfJump(destiny, current + MSSizeOfSkip()));
                    MSWriteJump(current, destiny);
                }
            } else if (backup[offset] == 0xeb)
                MSWriteJump(current, area + offset + decode.len + *reinterpret_cast<int8_t *>(backup + offset + 1));
            else if (backup[offset] == 0xe9)
                MSWriteJump(current, area + offset + decode.len + *reinterpret_cast<int32_t *>(backup + offset + 1));
            else if (
                backup[offset] == 0xe3 ||
                (backup[offset] & 0xf0) == 0x70
            ) {
                MSWrite<uint8_t>(current, backup[offset]);
                MSWrite<uint8_t>(current, 2);
                MSWrite<uint8_t>(current, 0xeb);
                void *destiny(area + offset + decode.len + *reinterpret_cast<int8_t *>(backup + offset + 1));
                MSWrite<uint8_t>(current, MSSizeOfJump(destiny, current + 1));
                MSWriteJump(current, destiny);
            } else
#ifdef __LP64__
                copy:
#endif
            {
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

_extern void MSHookFunction(void *symbol, void *replace, void **result) {
    return SubstrateHookFunction(NULL, symbol, replace, result);
}

#if defined(__APPLE__) && defined(__arm__)
_extern void _Z14MSHookFunctionPvS_PS_(void *symbol, void *replace, void **result) {
    return MSHookFunction(symbol, replace, result);
}
#endif
