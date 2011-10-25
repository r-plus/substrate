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

    bool safe(false);
    if (false) safe: {
        safe = true;
        goto scan;
    }

    if (getenv("_MSSafeMode") != NULL)
        goto safe;

    if (_syscall(access(SubstrateLibrary_, R_OK | X_OK)) == -1)
        goto safe;

    switch (pid_t child = _syscall(fork())) {
        case -1:
            goto quit;

        case 0:
            _syscall(execle(path, path, NULL, (const char *[]) { SubstrateVariable_ "=" SubstrateLibrary_, "MSExitZero" "=" }));
            _exit(EXIT_FAILURE);

        default:
            int status;
            if (_syscall(waitpid(child, &status, 0)) == -1)
                goto safe;
            if (!WIFEXITED(status) || WEXITSTATUS(status) != EXIT_SUCCESS)
                goto safe;
    }

  scan:
    size_t size(0);
    for (char * const *env(envp); *env != NULL; ++env)
        ++size;

    char **envs(reinterpret_cast<char **>(malloc(sizeof(char *) * (size + 2))));
    if (envs == NULL)
        goto quit;

    size_t last(0);
    bool found(false);

    for (char * const *env(envp); *env != NULL; ++env) {
        const char *equal(strchr(*env, '='));
        if (equal == NULL)
            goto copy;

        if (false);
        else if (strncmp("_MSLaunchHandle", *env, equal - *env) == 0)
            continue;
        else if (strncmp("_MSPosixSpawn", *env, equal - *env) == 0)
            continue;
        else if (strncmp(SubstrateVariable_, *env, equal - *env) == 0) {
            char *&value(envs[last++]);

            if (!safe) {
                if (asprintf(&value, "%s:%s", *env, SubstrateLibrary_) == -1)
                    goto quit;
            } else {
                if (asprintf(&value, "%s=:%s:", SubstrateVariable_, *env + sizeof(SubstrateVariable_)) == -1)
                    goto quit;

                char *end(value + strlen(value));
                char *colon(value + sizeof(SubstrateVariable_));

                for (char *scan(colon); (scan = strstr(scan, ":" SubstrateLibrary_ ":")) != NULL; ) {
                    memcpy(scan, scan + sizeof(SubstrateLibrary_), end - scan - sizeof(SubstrateLibrary_) + 1);
                    end -= sizeof(SubstrateLibrary_);
                }

                memcpy(colon, colon + 1, end - colon - 1);
                end[-2] = '\0';
            }

            continue;
        }

      copy:
        envs[last++] = strdup(*env);
    }

    if (!safe && !found)
        envs[last++] = strdup(SubstrateVariable_ "=" SubstrateLibrary_);

    envs[last++] = NULL;

    int value(_posix_spawn(pid, path, file_actions, attrp, argv, envs));

    for (char * const *env(envs); *env != NULL; ++env)
        free(*env);
    free(envs);

    return value;
}

template <typename Left_, typename Right_>
static void MSReinterpretAssign(Left_ &left, const Right_ &right) {
    left = reinterpret_cast<Left_>(right);
}

MSInitialize {
    Dl_info info;
    if (dladdr(reinterpret_cast<void *>(&$posix_spawn), &info) == 0)
        return;
    void *handle(dlopen(info.dli_fname, RTLD_NOLOAD));

    if (const char *cache = getenv("_MSPosixSpawn")) {
        MSReinterpretAssign(_posix_spawn, strtoull(cache, NULL, 0));
        MSHookFunction(&posix_spawn, &$posix_spawn);
    } else {
        MSHookFunction(&posix_spawn, MSHake(posix_spawn));

        char cache[32];
        sprintf(cache, "%p", _posix_spawn);
        setenv("_MSPosixSpawn", cache, false);
    }

    if (const char *cache = getenv("_MSLaunchHandle")) {
        void *obsolete;
        MSReinterpretAssign(obsolete, strtoull(cache, NULL, 0));
        dlclose(obsolete);
    }

    char cache[32];
    sprintf(cache, "%p", handle);
    setenv("_MSLaunchHandle", cache, true);
}
