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

#include <Foundation/Foundation.h>

#include <mach/mach_init.h>
#include <mach/vm_map.h>

#include <stdio.h>

#include "Common.hpp"
#include "Cydia.hpp"

void FinishCydia(const char *finish) {
    if (finish == NULL)
        return;

    const char *cydia(getenv("CYDIA"));
    if (cydia == NULL)
        return;


    // XXX: I think I'd like to rewrite this code using C++
    int fd([[[[NSString stringWithUTF8String:cydia] componentsSeparatedByString:@" "] objectAtIndex:0] intValue]);

    FILE *fout(fdopen(fd, "w"));
    fprintf(fout, "finish:%s\n", finish);
    fclose(fout);
}

ForkBugStatus DetectForkBug() {
    // XXX: I am not certain if I should deallocate this port
    mach_port_t self(mach_task_self());
    int page(getpagesize());

    volatile uint8_t *data(reinterpret_cast<volatile uint8_t *>(&fopen));
    uintptr_t base(reinterpret_cast<uintptr_t>(data) / page * page);

    vm_protect(self, base, page, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    data[0] = data[0];
    vm_protect(self, base, page, FALSE, VM_PROT_READ | VM_PROT_EXECUTE | VM_PROT_COPY);

    pid_t pid(fork());
    if (pid == 0) {
        fopen("/tmp/fork", "rb");
        _exit(EXIT_SUCCESS);
    }

    int status;
    if (_syscall(waitpid(pid, &status, 0) == -1)) {
        fprintf(stderr, "waitpid() -> %d\n", errno);
        return ForkBugUnknown;
    }

    if (WIFEXITED(status) && WEXITSTATUS(status) == EXIT_SUCCESS)
        return ForkBugMissing;
    else
        // XXX: consider checking for a killed status, and returning ForBugUnknown if not
        return ForkBugPresent;
}
