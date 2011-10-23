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

#include <CydiaSubstrate/CydiaSubstrate.h>
#include <stdio.h>

int main(int argc, const char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "usage: %s <pid> <dylib>\n", argv[0]);
        return 1;
    }

    pid_t pid(strtoul(argv[1], NULL, 10));
    const char *library(argv[2]);

    if (!MSHookProcess(pid, library)) {
        fprintf(stderr, "MSHookProcess() failed.\n");
        return 1;
    }

    return 0;
}
