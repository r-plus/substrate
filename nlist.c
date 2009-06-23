#if 0
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
 *	This product includes software developed by the University of
 *	California, Berkeley and its contributors.
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

#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>

#define BSD_KERNEL_PRIVATE
#include <arm/exec.h>

#include <sys/mman.h>
#include <sys/stat.h>

#include <sys/types.h>
#include <unistd.h>

#include <stdlib.h>

int $__fdnlist(int fd, struct nlist *list) {
	register struct nlist *p, *q;
	register int n, m;
	int maxlen, nreq;
	off_t sa;		/* symbol address */
	off_t ss;		/* start of strings */
	struct exec buf;
        struct nlist *space;
	unsigned  arch_offset = 0;

	maxlen = 0;
	for (q = list, nreq = 0; q->n_un.n_name && q->n_un.n_name[0]; q++, nreq++) {
		q->n_type = 0;
		q->n_value = 0;
		q->n_desc = 0;
		q->n_sect = 0;
		n = strlen(q->n_un.n_name);
		if (n > maxlen)
			maxlen = n;
	}
	if (read(fd, (char *)&buf, sizeof(buf)) != sizeof(buf) ||
	    (N_BADMAG(buf) && *((long *)&buf) != MH_MAGIC &&
	     NXSwapBigLongToHost(*((long *)&buf)) != FAT_MAGIC)) {
		return (-1);
	}

	/* Deal with fat file if necessary */
	if (NXSwapBigLongToHost(*((long *)&buf)) == FAT_MAGIC) {
		struct host_basic_info hbi;
		struct fat_header fh;
		struct fat_arch *fat_archs, *fap;
		unsigned i;
		host_t host;

		/* Get our host info */
		host = mach_host_self();
		i = HOST_BASIC_INFO_COUNT;
		if (host_info(host, HOST_BASIC_INFO,
			      (host_info_t)(&hbi), &i) != KERN_SUCCESS) {
			return (-1);
		}
		mach_port_deallocate(mach_task_self(), host);
		  
		/* Read in the fat header */
		lseek(fd, 0, SEEK_SET);
		if (read(fd, (char *)&fh, sizeof(fh)) != sizeof(fh)) {
			return (-1);
		}

		/* Convert fat_narchs to host byte order */
		fh.nfat_arch = NXSwapBigLongToHost(fh.nfat_arch);

		/* Read in the fat archs */
		fat_archs = (struct fat_arch *)malloc(fh.nfat_arch *
						      sizeof(struct fat_arch));
		if (fat_archs == NULL) {
			return (-1);
		}
		if (read(fd, (char *)fat_archs,
			 sizeof(struct fat_arch) * fh.nfat_arch) !=
		    sizeof(struct fat_arch) * fh.nfat_arch) {
			free(fat_archs);
			return (-1);
		}

		/*
		 * Convert archs to host byte ordering (a constraint of
		 * cpusubtype_getbestarch()
		 */
		for (i = 0; i < fh.nfat_arch; i++) {
			fat_archs[i].cputype =
				NXSwapBigLongToHost(fat_archs[i].cputype);
			fat_archs[i].cpusubtype =
			      NXSwapBigLongToHost(fat_archs[i].cpusubtype);
			fat_archs[i].offset =
				NXSwapBigLongToHost(fat_archs[i].offset);
			fat_archs[i].size =
				NXSwapBigLongToHost(fat_archs[i].size);
			fat_archs[i].align =
				NXSwapBigLongToHost(fat_archs[i].align);
		}

#if	CPUSUBTYPE_SUPPORT
		fap = cpusubtype_getbestarch(hbi.cpu_type, hbi.cpu_subtype,
					     fat_archs, fh.nfat_arch);
#else
#warning	Use the cpusubtype functions!!!
		fap = NULL;
		for (i = 0; i < fh.nfat_arch; i++) {
			if (fat_archs[i].cputype == hbi.cpu_type) {
				fap = &fat_archs[i];
				break;
			}
		}
#endif	/* CPUSUBTYPE_SUPPORT */
		if (!fap) {
			free(fat_archs);
			return (-1);
		}
		arch_offset = fap->offset;
		free(fat_archs);

		/* Read in the beginning of the architecture-specific file */
		lseek(fd, arch_offset, SEEK_SET);
		if (read(fd, (char *)&buf, sizeof(buf)) != sizeof(buf)) {
			return (-1);
		}
	}
		
	if (*((long *)&buf) == MH_MAGIC) {
	    struct mach_header mh;
	    struct load_command *load_commands, *lcp;
	    struct symtab_command *stp;
	    long i;

		lseek(fd, arch_offset, SEEK_SET);
		if (read(fd, (char *)&mh, sizeof(mh)) != sizeof(mh)) {
			return (-1);
		}
		load_commands = (struct load_command *)malloc(mh.sizeofcmds);
		if (load_commands == NULL) {
			return (-1);
		}
		if (read(fd, (char *)load_commands, mh.sizeofcmds) !=
		    mh.sizeofcmds) {
			free(load_commands);
			return (-1);
		}
		stp = NULL;
		lcp = load_commands;
		for (i = 0; i < mh.ncmds; i++) {
			if (lcp->cmdsize % sizeof(long) != 0 ||
			    lcp->cmdsize <= 0 ||
			    (char *)lcp + lcp->cmdsize >
			    (char *)load_commands + mh.sizeofcmds) {
				free(load_commands);
				return (-1);
			}
			if (lcp->cmd == LC_SYMTAB) {
				if (lcp->cmdsize !=
				   sizeof(struct symtab_command)) {
					free(load_commands);
					return (-1);
				}
				stp = (struct symtab_command *)lcp;
				break;
			}
			lcp = (struct load_command *)
			      ((char *)lcp + lcp->cmdsize);
		}
		if (stp == NULL) {
			free(load_commands);
			return (-1);
		}
		sa = stp->symoff + arch_offset;
		ss = stp->stroff + arch_offset;
		n = stp->nsyms * sizeof(struct nlist);
		free(load_commands);
	}
	else {
		sa = N_SYMOFF(buf) + arch_offset;
		ss = sa + buf.a_syms + arch_offset;
		n = buf.a_syms;
	}

    struct stat stat;
    if (fstat(fd, &stat) == -1)
        return -1;

    size_t size = stat.st_size;
    void *base = mmap(NULL, size, PROT_READ, MAP_FILE | MAP_SHARED, fd, 0);
    if (base == MAP_FAILED)
        return -1;

    space = (struct nlist *) ((char *) base + sa);

    for (m = 0; m != n; ++m) {
        q = &space[m];
        if (q->n_un.n_strx == 0 || q->n_type & N_STAB)
            continue;

        const char *nambuf = (const char *) base + ss + q->n_un.n_strx;

        for (p = list; p->n_un.n_name && p->n_un.n_name[0]; p++)
            if (strcmp(p->n_un.n_name, nambuf) == 0) {
                p->n_value = q->n_value;
                p->n_type = q->n_type;
                p->n_desc = q->n_desc;
                p->n_sect = q->n_sect;

                if (--nreq == 0)
                    goto done;
                break;
            }
    }

  done:
    /* XXX: error? */
    munmap(base, size);

    return nreq;
}
