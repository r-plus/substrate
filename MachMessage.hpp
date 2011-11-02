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

#ifndef SUBSTRATE_MACHMESSAGE_HPP
#define SUBSTRATE_MACHMESSAGE_HPP

#ifdef __arm__
extern mach_msg_return_t MS_mach_msg_trap(mach_msg_header_t *, mach_msg_option_t, mach_msg_size_t, mach_msg_size_t, mach_port_name_t, mach_msg_timeout_t, mach_port_name_t);
extern mach_msg_return_t MS_vm_protect_trap(vm_map_t, vm_address_t, vm_size_t, boolean_t, vm_prot_t);
#else
extern "C" mach_msg_return_t mach_msg_trap(mach_msg_header_t *, mach_msg_option_t, mach_msg_size_t, mach_msg_size_t, mach_port_name_t, mach_msg_timeout_t, mach_port_name_t);
#define MS_mach_msg_trap mach_msg_trap

static _finline MS_vm_protect_trap(vm_map_t, vm_address_t, vm_size_t, boolean_t, vm_prot_t) {
    return MACH_SEND_INVALID_DEST;
}
#endif

#endif//SUBSTRATE_MACHMESSAGE_HPP
