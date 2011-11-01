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
#include "ThreadSpecific.hpp"
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

ThreadSpecific<mach_port_t> reply_;

static mach_port_t MS_mig_get_reply_port() {
    return reply_;
}

#define mach_msg MS_mach_msg
#define mig_get_reply_port MS_mig_get_reply_port
#include "MachProtect.h"
#include "MachProtect.c"
#undef mig_get_reply_port
#undef mach_msg
#else
#define MS_vm_protect vm_protect
#endif

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
        MSLog(MSLogLevelError, "MS:Error:allocator != NULL");
        return NULL;
    }

    if (size == 0)
        return NULL;

#ifdef __arm__
    reply_ = mig_get_reply_port();
#endif

    int page(getpagesize());

    // XXX: I am not certain if I should deallocate this port
    mach_port_t self(mach_task_self());
    uintptr_t base(reinterpret_cast<uintptr_t>(data) / page * page);
    size_t width(((reinterpret_cast<uintptr_t>(data) + size - 1) / page + 1) * page - base);

    // XXX: this code should detect if RWX is available, and use it while editing for thread-safety

    if (kern_return_t error = MS_vm_protect(self, base, width, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY)) {
        MSLog(MSLogLevelError, "MS:Error:vm_protect() = %d", error);
        return NULL;
    }

    return new __SubstrateMemory(self, base, width);
}

extern "C" void SubstrateMemoryRelease(SubstrateMemoryRef memory) {
    if (kern_return_t error = MS_vm_protect(memory->self_, memory->base_, memory->width_, FALSE, VM_PROT_READ | VM_PROT_EXECUTE | VM_PROT_COPY))
        MSLog(MSLogLevelError, "MS:Error:vm_protect() = %d", error);
    delete memory;
}
