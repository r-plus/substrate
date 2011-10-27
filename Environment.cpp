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

#include <stdlib.h>
#include <string.h>

#include "Log.hpp"
#include "Environment.hpp"

void MSClearEnvironment() {
    setenv(SubstrateSafeMode_, "1", false);

    char *dil(getenv(SubstrateVariable_));
    if (dil == NULL) {
        MSLog(MSLogLevelError, "MS:Error: %s is unset?", SubstrateVariable_);
        return;
    }

    size_t length(strlen(dil));
    char buffer[length + 3];

    buffer[0] = ':';
    memcpy(buffer + 1, dil, length);
    buffer[length + 1] = ':';
    buffer[length + 2] = '\0';

    char *index(strstr(buffer, ":" SubstrateLibrary_ ":"));
    if (index == NULL) {
        MSLog(MSLogLevelError, "MS:Error: dylib not in %s", SubstrateVariable_);
        return;
    }

    size_t skip(sizeof(SubstrateLibrary_));
    if (length == skip - 1) {
        unsetenv(SubstrateVariable_);
        return;
    }

    buffer[length + 1] = '\0';
    memmove(index + 1, index + 1 + skip, length - (index - buffer) - skip + 2);
    setenv(SubstrateVariable_, buffer + 1, true);
}
