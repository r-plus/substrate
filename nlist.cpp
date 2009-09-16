#if 1
/* Trace Profiler {{{ */
#include <sys/time.h>
#include <stdbool.h>

static struct timeval _ltv;
static bool _itv;

#define _trace() do { \
    struct timeval _ctv; \
    gettimeofday(&_ctv, NULL); \
    if (!_itv) { \
        _itv = true; \
        _ltv = _ctv; \
    } \
    fprintf(stderr, "%lu.%.6u[%f]:_trace()@%s:%u[%s]\n", \
        _ctv.tv_sec, _ctv.tv_usec, \
        (_ctv.tv_sec - _ltv.tv_sec) + (_ctv.tv_usec - _ltv.tv_usec) / 1000000.0, \
        __FILE__, __LINE__, __FUNCTION__\
    ); \
    _ltv = _ctv; \
} while (false)
/* }}} */
#endif

/*
 * Copyright (c) 1999 Apple Computer, Inc. All rights reserved.
 *
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */
/*
 * Copyright (c) 1989, 1993
 * The Regents of the University of California.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. All advertising materials mentioning features or use of this software
 *    must display the following acknowledgement:
 *        This product includes software developed by the University of
 *        California, Berkeley and its contributors.
 * 4. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include <mach/mach.h>
#include <mach/mach_init.h>

#include <mach-o/dyld.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>

#define BSD_KERNEL_PRIVATE
#include <arm/exec.h>

#include <sys/mman.h>
#include <sys/stat.h>

#include <sys/types.h>
#include <unistd.h>

#include <cstdio>
#include <cstdlib>

static int MSMachONameList_(const uint8_t *base, struct nlist *list, bool file) {
    struct nlist *p;
    const struct nlist *q;
    int nreq;

    for (p = list, nreq = 0; p->n_un.n_name && p->n_un.n_name[0]; ++p, ++nreq) {
        p->n_type = 0;
        p->n_value = 0;
        p->n_desc = 0;
        p->n_sect = 0;
    }

    const struct exec *buf(reinterpret_cast<const struct exec *>(base));

    if (NXSwapBigLongToHost(buf->a_magic) == FAT_MAGIC) {
        struct host_basic_info hbi; {
            host_t host(mach_host_self());
            mach_msg_type_number_t count(HOST_BASIC_INFO_COUNT);
            if (host_info(host, HOST_BASIC_INFO, reinterpret_cast<host_info_t>(&hbi), &count) != KERN_SUCCESS)
                return -1;
            mach_port_deallocate(mach_task_self(), host);
        }

        const struct fat_header *fh(reinterpret_cast<const struct fat_header *>(base));
        uint32_t nfat_arch(NXSwapBigLongToHost(fh->nfat_arch));
        const struct fat_arch *fat_archs(reinterpret_cast<const struct fat_arch *>(fh + 1));

        for (uint32_t i(0); i != nfat_arch; ++i) {
            cpu_type_t cputype(NXSwapBigLongToHost(fat_archs[i].cputype));
            if (cputype != hbi.cpu_type)
                continue;
            buf = reinterpret_cast<const struct exec *>(base + NXSwapBigLongToHost(fat_archs[i].offset));
            goto thin;
        }

        return -1;
    }

  thin:
    const struct nlist *symbols;
    const char *strings;
    size_t n;

    if (buf->a_magic == MH_MAGIC) {
        const struct mach_header *mh(reinterpret_cast<const struct mach_header *>(base));
        const struct load_command *load_commands(reinterpret_cast<const struct load_command *>(mh + 1));

        const struct symtab_command *stp(NULL);

        const struct load_command *lcp(load_commands);
        for (uint32_t i(0); i != mh->ncmds; ++i, lcp = reinterpret_cast<const struct load_command *>(reinterpret_cast<const uint8_t *>(lcp) + lcp->cmdsize)) {
            if (
                lcp->cmdsize % sizeof(long) != 0 || lcp->cmdsize <= 0 ||
                reinterpret_cast<const uint8_t *>(lcp) + lcp->cmdsize > reinterpret_cast<const uint8_t *>(load_commands) + mh->sizeofcmds
            )
                return -1;
            if (lcp->cmd == LC_SYMTAB) {
                if (lcp->cmdsize != sizeof(struct symtab_command))
                    return -1;
                stp = reinterpret_cast<const struct symtab_command *>(lcp);
                goto found;
            }
        }

        return -1;

      found:
        n = stp->nsyms;

        if (file) {
            symbols = reinterpret_cast<const struct nlist *>(base + stp->symoff);
            strings = reinterpret_cast<const char *>(base + stp->stroff);
        } else {
            symbols = NULL;
            strings = NULL;

            lcp = load_commands;
            for (uint32_t i(0); i != mh->ncmds; ++i, lcp = reinterpret_cast<const struct load_command *>(reinterpret_cast<const uint8_t *>(lcp) + lcp->cmdsize)) {
                if (
                    lcp->cmdsize % sizeof(long) != 0 || lcp->cmdsize <= 0 ||
                    reinterpret_cast<const uint8_t *>(lcp) + lcp->cmdsize > reinterpret_cast<const uint8_t *>(load_commands) + mh->sizeofcmds
                )
                    return -1;
                if (lcp->cmd == LC_SEGMENT) {
                    if (lcp->cmdsize < sizeof(struct symtab_command))
                        return -1;
                    const struct segment_command *segment(reinterpret_cast<const struct segment_command *>(lcp));
                    if (stp->symoff >= segment->fileoff && stp->symoff < segment->fileoff + segment->filesize)
                        symbols = reinterpret_cast<const struct nlist *>(stp->symoff - segment->fileoff + segment->vmaddr);
                    if (stp->stroff >= segment->fileoff && stp->stroff < segment->fileoff + segment->filesize)
                        strings = reinterpret_cast<const char *>(stp->stroff - segment->fileoff + segment->vmaddr);
                }
            }

            if (symbols == NULL || strings == NULL) {
                _trace();
                return -1;
            }
        }
    } else {
        /* XXX: is this right anymore?!? */
        symbols = reinterpret_cast<const struct nlist *>(base + N_SYMOFF(*buf));
        strings = reinterpret_cast<const char *>(reinterpret_cast<const uint8_t *>(symbols) + buf->a_syms);
        n = buf->a_syms / sizeof(struct nlist);
    }

    for (size_t m(0); m != n; ++m) {
        q = &symbols[m];
        if (q->n_un.n_strx == 0 || (q->n_type & N_STAB) != 0)
            continue;

        const char *nambuf(strings + q->n_un.n_strx);

        for (p = list; p->n_un.n_name && p->n_un.n_name[0]; ++p)
            if (strcmp(p->n_un.n_name, nambuf) == 0) {
                p->n_value = q->n_value;
                p->n_type = q->n_type;
                p->n_desc = q->n_desc;
                p->n_sect = q->n_sect;

                if (nreq == 0)
                    return 0;
                break;
            }
    }

    return nreq;
}

extern "C" int $__fdnlist(int fd, struct nlist *list) {
    struct stat stat;
    if (fstat(fd, &stat) == -1)
        return -1;

    size_t size = stat.st_size;
    void *base = mmap(NULL, size, PROT_READ, MAP_FILE | MAP_SHARED, fd, 0);
    if (base == MAP_FAILED)
        return -1;

    int value(MSMachONameList_(reinterpret_cast<const uint8_t *>(base), list, true));

    /* XXX: error? */
    munmap(base, size);
    return value;
}

int (*_nlist)(const char *file, struct nlist *list);

extern "C" int $nlist(const char *file, struct nlist *list) {
    for (uint32_t index(0), count(_dyld_image_count()); index != count; ++index)
        if (strcmp(_dyld_get_image_name(index), file) == 0)
            return MSMachONameList_(reinterpret_cast<const uint8_t *>(_dyld_get_image_header(index)), list, false);
    return (*_nlist)(file, list);
}
