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

#include "CydiaSubstrate.h"

#include "Log.hpp"

#include <launch.h>

#include <unistd.h>
#include <errno.h>
#include <syslog.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>

#include <spawn.h>

#include "Environment.hpp"

#define _syscall(expr) ({ \
    __typeof__(expr) _value; \
    for(;;) if ((long) (_value = (expr)) != -1 || errno != EINTR) \
        break; \
    _value; \
})

MSHook(int, posix_spawn, pid_t *pid, const char *path, const posix_spawn_file_actions_t *file_actions, const posix_spawnattr_t *attrp, char * const argv[], char * const envp[]) {
    if (false) quit:
        return _posix_spawn(pid, path, file_actions, attrp, argv, envp);

    if (_syscall(access(SubstrateLibrary_, R_OK | X_OK)) == -1)
        goto quit;

    switch (pid_t child = _syscall(fork())) {
        case -1: {
            goto quit;
        }

        case 0: {
            setenv(SubstrateVariable_, SubstrateLibrary_, true);
            setenv("MSExitZero", "", true);
            char *args[] = { strdup(path), NULL };
            _syscall(execv(path, args));
            _exit(EXIT_FAILURE);
        }

        default: {
            int status;
            if (_syscall(waitpid(child, &status, 0)) == -1)
                goto quit;
            if (!WIFEXITED(status) || WEXITSTATUS(status) != EXIT_SUCCESS)
                goto quit;
        }
    }

    size_t size(0);
    for (char * const *env(envp); *env != NULL; ++env)
        ++size;

    char **envs(new char *[size + 2]);

    size_t last(0);
    bool found(false);

    for (char * const *env(envp); *env != NULL; ++env)
        if (strncmp(*env, SubstrateVariable_ "=", sizeof(SubstrateVariable_)) != 0)
            envs[last++] = *env;
        else {
            found = true;

            if (strlen(*env) == sizeof(SubstrateVariable_))
                envs[last++] = strdup(SubstrateVariable_ "=" SubstrateLibrary_);
            else
                asprintf(&envs[last++], "%s:%s", *env, SubstrateLibrary_);
        }

    if (!found)
        envs[last++] = strdup(SubstrateVariable_ "=" SubstrateLibrary_);

    envs[last++] = NULL;

    return _posix_spawn(pid, path, file_actions, attrp, argv, envs);
}

MSInitialize {
    MSHookFunction(&posix_spawn, MSHake(posix_spawn));
}
