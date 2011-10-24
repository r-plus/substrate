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
#include <syslog.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>

#include <spawn.h>

#include "Environment.hpp"

static int PosixSpawn(int (*spawn)(pid_t *, const char *, const posix_spawn_file_actions_t *, const posix_spawnattr_t *, char * const [], char * const []), pid_t *pid, const char *file2exec, const posix_spawn_file_actions_t *file_actions, const posix_spawnattr_t *attrp, char * const argv[], char * const envp[]) {
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

    return (*spawn)(pid, file2exec, file_actions, attrp, argv, envs);
}

MSHook(int, posix_spawn, pid_t *pid, const char *path, const posix_spawn_file_actions_t *file_actions, const posix_spawnattr_t *attrp, char * const argv[], char * const envp[]) {
    return PosixSpawn(_posix_spawn, pid, path, file_actions, attrp, argv, envp);
}

MSHook(int, posix_spawnp, pid_t *pid, const char *file, const posix_spawn_file_actions_t *file_actions, const posix_spawnattr_t *attrp, char * const argv[], char * const envp[]) {
    return PosixSpawn(_posix_spawnp, pid, file, file_actions, attrp, argv, envp);
}

MSInitialize {
    MSHookFunction(&posix_spawn, MSHake(posix_spawn));
    MSHookFunction(&posix_spawnp, MSHake(posix_spawnp));
}
