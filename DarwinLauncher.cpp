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

#include <sys/stat.h>

#include <spawn.h>

#include "Common.hpp"
#include "Environment.hpp"

#include <crt_externs.h>
#define environ (*_NSGetEnviron())

MSHook(int, posix_spawn, pid_t *pid, const char *path, const posix_spawn_file_actions_t *file_actions, const posix_spawnattr_t *attrp, char * const argv[], char * const envp[]) {
    // quit is a goto target that is used below to exit this function without manipulating envp

    if (false) quit:
        return _posix_spawn(pid, path, file_actions, attrp, argv, envp);


    // safe is a goto target that is used below to indicate that Substrate should be removed from envp

    bool safe(false);
    if (false) safe: {
        safe = true;
        goto scan;
    }


    // we use these arguments below, so we need to fix them or fail early

    if (path == NULL)
        goto quit;
    if (envp == NULL)
        envp = environ;


    // it is possible we are still installed in the kernel, even though substrate was removed
    // in this situation, it is safest if we goto safe, not quit, to remove DYLD_INSERT_LIBRARIES

    if (_syscall(access(SubstrateLibrary_, R_OK | X_OK)) == -1)
        goto safe;


    // if a process wants to turn off Substrate for its children, it needs to communicate this to us
    // a process can also indicate "I'm good, just do it", bypassing the later (expensive) safety checks

    for (char * const *env(envp); *env != NULL; ++env)
        if (false);
        else if (strncmp(SubstrateSafeMode_ "=", *env, sizeof(SubstrateSafeMode_)) == 0) {
            const char *value(*env + sizeof(SubstrateSafeMode_));

            if (false);
            else if (strcmp(value, "0") == 0 || strcmp(value, "NO") == 0)
                goto scan;
            else if (strcmp(value, "1") == 0 || strcmp(value, "YES") == 0 || strcmp(value, "") == 0)
                goto safe;
            else goto quit;
        }


    // DYLD_INSERT_LIBRARIES does not work in processes that are setugid
    // testing this condition prevents us from having a runaway test below

    struct stat info;
    if (_syscall(stat(path, &info)) == -1)
        goto safe;
    if ((info.st_mode & S_ISUID) != 0 && getuid() != info.st_uid)
        goto safe;
    // XXX: technically, if this user is not a member of the group
    if ((info.st_mode & S_ISGID) != 0 && getgid() != info.st_gid)
        goto safe;


    // some jailbreaks (example: iOS 3.0 PwnageTool) have broken (restrictive) sandbox patches
    // spawning the process with DYLD_INSERT_LIBRARIES causes them to immediately crash

    switch (pid_t child = _syscall(fork())) {
        case -1:
            goto quit;

        case 0:
            // XXX: figure out a way to turn off CrashReporter for this process
            _syscall(execle(path, path, NULL, (const char *[]) { SubstrateVariable_ "=" SubstrateLibrary_, "MSExitZero" "=", NULL }));
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


    // fail is a goto target that can be used to deallocate our new environment and quit

    if (false) fail: {
        for (size_t i(0); i != last; ++i)
            free(envs[i]);
        free(envs);
        goto quit;
    }


    bool found(false);

    for (char * const *env(envp); *env != NULL; ++env) {
        const char *equal(strchr(*env, '='));
        if (equal == NULL)
            goto copy;

        #define envcmp(value) ( \
            (equal - *env == sizeof(value) - 1) && \
            strncmp(value, *env, sizeof(value) - 1) == 0 \
        )

        if (false);
        else if (envcmp("_MSLaunchHandle"))
            continue;
        else if (envcmp("_MSPosixSpawn"))
            continue;
        else if (envcmp(SubstrateVariable_)) {
            // if the variable is empty, let's just pretend we didn't find it (you with me? ;P)...
            // the problem is that the insanely hilarious code below doesn't work in this case

            if (equal[1] == '\0')
                continue;
            found = true;


            // our initial goal is to get a string :1:2:3: <- with leading and trailing colons
            // if we are adding the environment variable, then 1 will be the dylib being added

            const char *extra(safe ? "" : ":" SubstrateLibrary_);

            char *value;
            int count(asprintf(&value, "%s=%s:%s:", SubstrateVariable_, extra, equal + 1));
            if (count == -1)
                goto fail;


            // once that is complete, we will find the colon preceding the old content
            // this allows us to scan the string, removing any excess copies of :dylib

            // - strlen(equal + 1) <- subtract the bounded %s (orginal value)
            // - 1 - 1 <- subtract the leading and trailing colons around %s

            char *end(value + count);
            char *colon(end - 1 - strlen(equal + 1) - 1);

            for (char *scan(colon); (scan = strstr(scan, ":" SubstrateLibrary_ ":")) != NULL; ) {
                // end - scan <- all remaining characters
                // - sizeof(SubstrateLibrary_) <- subtract :dylib
                // + 1 <- add the null terminator

                memmove(scan, scan + sizeof(SubstrateLibrary_), end - scan - sizeof(SubstrateLibrary_) + 1);

                // move end of string back by :dylib length

                end -= sizeof(SubstrateLibrary_);
            }


            // if the variable is empty ("=:"), we just remove it entirely
            // end - value <- the total length of the string

            // sizeof(SubstrateVariable_) <- includes the =
            // + 1 <- we still need to compensate for the :

            if (end - value == sizeof(SubstrateVariable_) + 1) {
                free(value);
                continue;
            }


            // otherwise, we need to delete the leading and trailing colons
            // we reposition colon to the first colon (before our injection)

            colon = value + sizeof(SubstrateVariable_);
            memmove(colon, colon + 1, end - colon - 1);
            end[-2] = '\0';
            envs[last++] = value;
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
    // this installation routine keeps a reference to the current library in _MSLaunchHandle
    // dlopen() is called now, and dlclose() will be called in the new version during upgrade

    Dl_info info;
    if (dladdr(reinterpret_cast<void *>(&$posix_spawn), &info) == 0)
        return;
    void *handle(dlopen(info.dli_fname, RTLD_NOLOAD));


    // before we unload the previous version, we hook posix_spawn to call our replacements
    // the original posix_spawn (from Apple) is kept in _MSPosixSpawn for use by new versions

    if (const char *cache = getenv("_MSPosixSpawn")) {
        MSReinterpretAssign(_posix_spawn, strtoull(cache, NULL, 0));
        MSHookFunction(&posix_spawn, &$posix_spawn);
    } else {
        MSHookFunction(&posix_spawn, MSHake(posix_spawn));

        char cache[32];
        sprintf(cache, "%p", _posix_spawn);
        setenv("_MSPosixSpawn", cache, false);
    }


    // specifically after having updated posix_spawn, we can unload the previous version

    if (const char *cache = getenv("_MSLaunchHandle")) {
        void *obsolete;
        MSReinterpretAssign(obsolete, strtoull(cache, NULL, 0));
        dlclose(obsolete);
    }


    // as installation has completed, we now set _MSLaunchHandle to the address of this version

    char cache[32];
    sprintf(cache, "%p", handle);
    // XXX: there is a race condition installing new versions: need atomic get/setenv()
    setenv("_MSLaunchHandle", cache, true);
}
