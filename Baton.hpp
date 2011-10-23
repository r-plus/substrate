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

#include <dlfcn.h>
#include <mach/mach.h>
#include <sys/types.h>

struct Baton {
    void (*__pthread_set_self)(pthread_t);
    int (*pthread_create)(pthread_t *, const pthread_attr_t *, void *(*)(void *), void *);

    mach_port_t (*mach_thread_self)();
    kern_return_t (*thread_terminate)(thread_act_t);

    char *(*dlerror)();
    void *(*dlsym)(void *, const char *);

    char library[];
};
