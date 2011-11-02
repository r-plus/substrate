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

#include <mach/vm_map.h>

#ifdef __arm__

__attribute__((__naked__))
__attribute__((__noinline__))
mach_msg_return_t MS_mach_msg_trap(mach_msg_header_t *, mach_msg_option_t, mach_msg_size_t, mach_msg_size_t, mach_port_name_t, mach_msg_timeout_t, mach_port_name_t) {
    register mach_msg_return_t error asm("r0");

    asm volatile (
        "mov r12, sp\n"
        "push.w {r4, r5, r6, r8}\n"
        "ldm.w r12, {r4, r5, r6}\n"
        "mvn.w r12, #30\n"
        "svc 0x80\n"
        "pop.w {r4, r5, r6, r8}\n"
    : "=a" (error)
    :
    : "r1", "r2", "r3", "r4", "r5", "r6", "r8", "r12"
    );

    return error;
}

__attribute__((__naked__))
__attribute__((__noinline__))
mach_msg_return_t MS_vm_protect_trap(vm_map_t target_task, vm_address_t address, vm_size_t size, boolean_t set_maximum, vm_prot_t new_protection) {
    register mach_msg_return_t error asm("r0");

    asm volatile (
        "mov r12, sp\n"
        "push {r4, r5}\n"
        "ldr.w r4, [r12]\n"
        "mvn.w r12, #14\n"
        "svc 0x80\n"
        "pop {r4, r5}\n"
    : "=a" (error)
    :
    : "r1", "r2", "r3", "r4", "r5", "r12"
    );

    return error;
}

#endif
