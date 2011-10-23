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

#define _PTHREAD_ATTR_T
#include <pthread_internals.h>

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

    int (*pthread_detach)(pthread_t);
    dlset(baton, pthread_detach, "pthread_detach");

    pthread_t (*pthread_self)();
    dlset(baton, pthread_self, "pthread_self");

    pthread_detach(pthread_self());

    void *(*dlopen)(const char *, int);
    dlset(baton, dlopen, "dlopen");

    void *handle(dlopen(baton->library, RTLD_LAZY | RTLD_LOCAL));
    if (handle == NULL) {
        baton->dlerror();
        return NULL;
    }

    return NULL;
}

static void $bzero(void *data, size_t size) {
    char *bytes(reinterpret_cast<char *>(data));
    for (size_t i(0); i != size; ++i)
        bytes[i] = 0;
}

extern "C" void Start(Baton *baton) {
    struct _pthread self;
    $bzero(&self, sizeof(self));

    // this code comes from _pthread_set_self
    self.tsd[0] = &self;
    baton->__pthread_set_self(&self);

    pthread_t thread;
    baton->pthread_create(&thread, NULL, &Routine, baton);

    baton->thread_terminate(baton->mach_thread_self());
}
