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

#include "DarwinThreadInternal.hpp"

#include "CydiaSubstrate/CydiaSubstrate.h"
#include "Baton.hpp"

template <typename Type_>
static _finline void dlset(Baton *baton, Type_ &function, const char *name, void *handle = RTLD_DEFAULT) {
    function = reinterpret_cast<Type_>(baton->dlsym(handle, name));
    if (function == NULL)
        baton->dlerror();
}

void *Routine(void *arg) {
    Baton *baton(reinterpret_cast<Baton *>(arg));

    void *(*dlopen)(const char *, int);
    dlset(baton, dlopen, "dlopen");

    void *handle(dlopen(baton->library, RTLD_LAZY | RTLD_LOCAL));
    if (handle == NULL) {
        baton->dlerror();
        return NULL;
    }

    int (*dlclose)(void *);
    dlset(baton, dlclose, "dlclose");

    dlclose(handle);

    return NULL;
}


// I am unable to link against any external functions, so reimplement bzero
// XXX: there might be a gcc builtin for memset/bzero: use it instead?

static void $bzero(void *data, size_t size) {
    char *bytes(reinterpret_cast<char *>(data));
    for (size_t i(0); i != size; ++i)
        bytes[i] = 0;
}


extern "C" void Start(Baton *baton) {
    // normally, a pthread has a _pthread associated with it; pthread_t is a pointer to it
    // these are normally initialized by either _pthread_create or _pthread_struct_init
    // however, for our purposes, just initializing it to 0 is reasonably sufficient
    // XXX: look into using _pthread_create or _pthread_struct_init instead

    struct _pthread self;
    $bzero(&self, sizeof(self));


    // this code comes from _pthread_set_self, which is the startup routine of _pthread_body
    // XXX: on 2.x and above, __pthread_set_self doesn't even seem to do anything useful
    // XXX: if we use _pthread_create/_pthread_struct_init, the tsd[0] will be handled

    self.tsd[0] = &self;
    baton->__pthread_set_self(&self);


    // the current thread identifier is stored in the 0th thread-specific data slot
    // thread-specific data, especially the 0th slot, is often stored in hardware registers
    // the _pthread_setspecific_direct macro allows us to update these static entries
    // XXX: consider passing pthread_setspecific() and calling the slower routine

    _pthread_setspecific_direct(0, &self);


    pthread_t thread;
    baton->pthread_create(&thread, NULL, &Routine, baton);

    void *status;
    baton->pthread_join(thread, &status);

    // XXX: I am not certain if I should deallocate this port (an academic question, as I can't)
    baton->thread_terminate(baton->mach_thread_self());
}
