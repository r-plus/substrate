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

#define SubstrateInternal
#include "CydiaSubstrate.h"

#include <mach/mach_init.h>
#include <mach/vm_map.h>

#include <cstdio>
#include <unistd.h>

#ifdef __APPLE__
struct __SubstrateMemory {
    mach_port_t self_;
    uintptr_t base_;
    size_t width_;

    __SubstrateMemory(mach_port_t self, uintptr_t base, size_t width) :
        self_(self),
        base_(base),
        width_(width)
    {
    }
};

extern "C" SubstrateMemoryRef SubstrateMemoryCreate(SubstrateAllocatorRef allocator, SubstrateProcessRef process, void *data, size_t size) {
    if (allocator != NULL) {
        fprintf(stderr, "MS:Error:allocator != NULL\n");
        return NULL;
    }

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

    return new __SubstrateMemory(self, base, width);
}

extern "C" void SubstrateMemoryRelease(SubstrateMemoryRef memory) {
    if (kern_return_t error = vm_protect(memory->self_, memory->base_, memory->width_, FALSE, VM_PROT_READ | VM_PROT_EXECUTE | VM_PROT_COPY))
        fprintf(stderr, "MS:Error:vm_protect() = %d\n", error);
    delete memory;
}
#endif
