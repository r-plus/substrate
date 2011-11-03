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

#define SubstrateInternal
#include "CydiaSubstrate.h"

#include "Log.hpp"

#include <mach/mach_init.h>
#include <mach/vm_map.h>

#include <stdio.h>
#include <unistd.h>

#ifdef __arm__

#include "MachMessage.hpp"

static mach_msg_return_t MS_mach_msg(mach_msg_header_t *msg, mach_msg_option_t option, mach_msg_size_t send_size, mach_msg_size_t rcv_size, mach_port_name_t rcv_name, mach_msg_timeout_t timeout, mach_port_name_t notify) {
    for (;;) switch (mach_msg_return_t error = MS_mach_msg_trap(msg, option, send_size, rcv_size, rcv_name, timeout, notify)) {
        case MACH_SEND_INTERRUPT:
            break;

        case MACH_RCV_INTERRUPT:
            option &= ~MACH_SEND_MSG;
            break;

        default:
            return error;
    }
}

#define mach_msg MS_mach_msg
#include "MachProtect.h"
#include "MachProtect.c"
#undef mach_msg

static kern_return_t MS_vm_protect(mach_port_t reply_port, vm_map_t target_task, vm_address_t address, vm_size_t size, boolean_t set_maximum, vm_prot_t new_protection) {
    kern_return_t error;


#if 0
    // on iOS >= 5.0, Apple now provides a number of system call traps for common mach interfaces, like vm_map
    // XXX: this code, when tested on iOS 2.2 (not tested on >> 2.2 && << 5.0) returns 0x807 with signal "?"

    error = MS_vm_protect_trap(target_task, address, size, set_maximum, new_protection);
    if (error != MACH_SEND_INVALID_DEST)
        return error;
#endif


    // 3803 is vm_map's vm_protect. it is guaranteed to take 32-bit arguments on all platforms, which is convenient
    // unfortunately, this kernel-side interface seems to be missing on at least iOS 4.0, so we cannot rely on it

    error = MS_vm_protect_mach(3803, reply_port, target_task, address, size, set_maximum, new_protection);
    if (error != MIG_BAD_ID)
        return error;


    // 4802 is mach_vm's mach_vm_protect. it is supposed to always take "the largest size type for the platform"
    // unfortunately, while on iOS << 5.0 ARM was considered 32-bit, with iOS 5.0 Apple decided ARM could be 64-bit
    // therefore, we cannot know what size arguments to pass to this function, and Apple has nigh unto deprecated it
    // thankfully, current devices that have a 64-bit mach_vm_protect also support the 32-bit vm_protect interface

    error = MS_vm_protect_mach(4802, reply_port, target_task, address, size, set_maximum, new_protection);
    if (error != MIG_BAD_ID)
        return error;


    return error;
}

#else

#define MS_vm_protect(a0, a1, a2, a3, a4, a5) vm_protect(a1, a2, a3, a4, a5)

#endif

struct __SubstrateMemory {
    mach_port_t reply_;
    mach_port_t self_;
    uintptr_t base_;
    size_t width_;

    __SubstrateMemory(mach_port_t reply, mach_port_t self, uintptr_t base, size_t width) :
        reply_(reply),
        self_(self),
        base_(base),
        width_(width)
    {
    }
};

extern "C" SubstrateMemoryRef SubstrateMemoryCreate(SubstrateAllocatorRef allocator, SubstrateProcessRef process, void *data, size_t size) {
    if (allocator != NULL) {
        MSLog(MSLogLevelError, "MS:Error:allocator != NULL");
        return NULL;
    }

    if (size == 0)
        return NULL;

    int page(getpagesize());

    mach_port_t reply(mig_get_reply_port());
    mach_port_t self(mach_task_self());

    uintptr_t base(reinterpret_cast<uintptr_t>(data) / page * page);
    size_t width(((reinterpret_cast<uintptr_t>(data) + size - 1) / page + 1) * page - base);


    // the max_protection of this memory, on ARM, is normally r-x (as it is currently executable and marked clean)
    // however, we need to write to it; mprotect() can't do it, so we use vm_protect(VM_PROT_COPY), to get a new page

    // XXX: I should try for RWX here, but it seriously never works and you get this irritating log:
    // kernel[0] <Debug>: EMBEDDED: vm_map_protect can't have both write and exec at the same time

    if (kern_return_t error = MS_vm_protect(reply, self, base, width, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY)) {
        MSLog(MSLogLevelError, "MS:Error:vm_protect() = %d", error);
        return NULL;
    }


    return new __SubstrateMemory(reply, self, base, width);
}

extern "C" void SubstrateMemoryRelease(SubstrateMemoryRef memory) {
    if (kern_return_t error = MS_vm_protect(memory->reply_, memory->self_, memory->base_, memory->width_, FALSE, VM_PROT_READ | VM_PROT_EXECUTE | VM_PROT_COPY))
        MSLog(MSLogLevelError, "MS:Error:vm_protect() = %d", error);
    delete memory;
}
