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

#include <mach/mach.h>
#include <mach/mach_init.h>

#include <mach-o/dyld.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>

#define BSD_KERNEL_PRIVATE
#include <machine/exec.h>

#include <sys/mman.h>
#include <sys/stat.h>

#include <sys/types.h>
#include <unistd.h>

#include <cstdio>
#include <cstdlib>

#include "CydiaSubstrate.h"

struct MSSymbolData {
    const char *name_;
    uint8_t type_;
    uint8_t sect_;
    int16_t desc_;
    uintptr_t value_;
};

#ifdef __LP64__
typedef struct nlist_64 MSNameList;
#else
typedef struct nlist MSNameList;
#endif

int MSMachONameList_(const uint8_t *base, struct MSSymbolData *list, size_t nreq) {
    const struct exec *buf(reinterpret_cast<const struct exec *>(base));

    if (OSSwapBigToHostInt32(buf->a_magic) == FAT_MAGIC) {
        struct host_basic_info hbi; {
            host_t host(mach_host_self());
            mach_msg_type_number_t count(HOST_BASIC_INFO_COUNT);
            if (host_info(host, HOST_BASIC_INFO, reinterpret_cast<host_info_t>(&hbi), &count) != KERN_SUCCESS)
                return -1;
            mach_port_deallocate(mach_task_self(), host);
        }

        const struct fat_header *fh(reinterpret_cast<const struct fat_header *>(base));
        uint32_t nfat_arch(OSSwapBigToHostInt32(fh->nfat_arch));
        const struct fat_arch *fat_archs(reinterpret_cast<const struct fat_arch *>(fh + 1));

        for (uint32_t i(0); i != nfat_arch; ++i)
            if (static_cast<cpu_type_t>(OSSwapBigToHostInt32(fat_archs[i].cputype)) == hbi.cpu_type) {
                buf = reinterpret_cast<const struct exec *>(base + OSSwapBigToHostInt32(fat_archs[i].offset));
                goto thin;
            }

        return -1;
    }

  thin:
    const MSNameList *symbols;
    const char *strings;
    size_t n;

    // XXX: this check looks really scary when it fails
    if (buf->a_magic == MH_MAGIC) {
        const struct mach_header *mh(reinterpret_cast<const struct mach_header *>(base));
        const struct load_command *load_commands(reinterpret_cast<const struct load_command *>(mh + 1));

        const struct symtab_command *stp(NULL);
        const struct load_command *lcp;

        lcp = load_commands;
        for (uint32_t i(0); i != mh->ncmds; ++i) {
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

            lcp = reinterpret_cast<const struct load_command *>(reinterpret_cast<const uint8_t *>(lcp) + lcp->cmdsize);
        }

        return -1;

      found:
        n = stp->nsyms;

        symbols = NULL;
        strings = NULL;

        lcp = load_commands;
        for (uint32_t i(0); i != mh->ncmds; ++i) {
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
                    symbols = reinterpret_cast<const MSNameList *>(stp->symoff - segment->fileoff + segment->vmaddr);
                if (stp->stroff >= segment->fileoff && stp->stroff < segment->fileoff + segment->filesize)
                    strings = reinterpret_cast<const char *>(stp->stroff - segment->fileoff + segment->vmaddr);
            }

            lcp = reinterpret_cast<const struct load_command *>(reinterpret_cast<const uint8_t *>(lcp) + lcp->cmdsize);
        }

        if (symbols == NULL || strings == NULL) {
            _trace();
            return -1;
        }
    } else {
        /* XXX: is this right anymore?!? */
        symbols = reinterpret_cast<const MSNameList *>(base + N_SYMOFF(*buf));
        strings = reinterpret_cast<const char *>(reinterpret_cast<const uint8_t *>(symbols) + buf->a_syms);
        n = buf->a_syms / sizeof(MSNameList);
    }

    for (size_t m(0); m != n; ++m) {
        const MSNameList *q(&symbols[m]);
        if (q->n_un.n_strx == 0 || (q->n_type & N_STAB) != 0)
            continue;

        const char *nambuf(strings + q->n_un.n_strx);

        for (size_t item(0); item != nreq; ++item) {
            struct MSSymbolData *p(list + item);
            if (strcmp(p->name_, nambuf) != 0)
                continue;

            p->value_ = q->n_value;
            p->type_ = q->n_type;
            p->desc_ = q->n_desc;
            p->sect_ = q->n_sect;

            if (--nreq == 0)
                return 0;
            break;
        }
    }

    return nreq;
}

#ifndef __LP64__
int (*_nlist)(const char *file, struct nlist *list);

extern "C" int $nlist(const char *file, struct nlist *names) {
    for (uint32_t image(0), count(_dyld_image_count()); image != count; ++image)
        if (strcmp(_dyld_get_image_name(image), file) == 0) {
            size_t count(0);
            for (struct nlist *name(names); name->n_un.n_name != NULL; ++name)
                ++count;

            MSSymbolData items[count];

            for (size_t index(0); index != count; ++index) {
                MSSymbolData &item(items[index]);
                struct nlist &name(names[index]);

                item.name_ = name.n_un.n_name;
                item.type_ = 0;
                item.sect_ = 0;
                item.desc_ = 0;
                item.value_ = 0;
            }

            int result(MSMachONameList_(reinterpret_cast<const uint8_t *>(_dyld_get_image_header(image)), items, count));

            for (size_t index(0); index != count; ++index) {
                MSSymbolData &item(items[index]);
                struct nlist &name(names[index]);

                name.n_type = item.type_;
                name.n_sect = item.sect_;
                name.n_desc = item.desc_;
                name.n_value = item.value_;
            }

            return result;
        }

    return (*_nlist)(file, names);
}

MSInitialize {
    MSHookFunction(&nlist, &$nlist, &_nlist);
}
#endif
