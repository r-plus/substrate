/* Cydia Substrate - Powerful Code Insertion Platform
 * Copyright (C) 2008-2010  Jay Freeman (saurik)
*/

/* GNU Lesser General Public License, Version 3 {{{ */
/*
 * Cycript is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or (at your
 * option) any later version.
 *
 * Cycript is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
 * License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with Cycript.  If not, see <http://www.gnu.org/licenses/>.
**/
/* }}} */

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <dlfcn.h>
#include <unistd.h>

#include "substrate.h"

MSInitialize {
    // Skype
    if (dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY | RTLD_NOLOAD) == NULL)
        return;

    // Maps
    dlopen("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation", RTLD_LAZY | RTLD_GLOBAL);

    dlopen("/Library/MobileSubstrate/MobileLoader.dylib", RTLD_LAZY | RTLD_GLOBAL);
}
