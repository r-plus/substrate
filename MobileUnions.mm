/* Cydia Substrate - Meta-Library Insert for iPhoneOS
 * Copyright (C) 2008  Jay Freeman (saurik)
*/

/*
 *        Redistribution and use in source and binary
 * forms, with or without modification, are permitted
 * provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the
 *    above copyright notice, this list of conditions
 *    and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the
 *    above copyright notice, this list of conditions
 *    and the following disclaimer in the documentation
 *    and/or other materials provided with the
 *    distribution.
 * 3. The name of the author may not be used to endorse
 *    or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,
 * BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
 * TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
 * ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

#include <substrate.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include <dirent.h>

#define UnionPath_ "/Library/MobileSubstrate/UnionFiles"

MSHook(int, open, const char *path, int flag, mode_t mode) {
    if (path != NULL && (flag & O_ACCMODE) == O_RDONLY && path[0] == '/') {
        size_t size(strlen(path));
        char *move(new char[size + sizeof(UnionPath_)]);
        memcpy(move, UnionPath_, sizeof(UnionPath_) - 1);
        memcpy(move + sizeof(UnionPath_) - 1, path, size + 1);

        int file;
        do file = _open(move, flag, mode);
        while (file == -1 && errno == EINTR);
        delete [] move;

        if (file != -1)
            return file;
    }

    return _open(path, flag, mode);
}

extern "C" void MSInitialize() {
    bool hook(false);

    if (DIR *dir = opendir(UnionPath_)) {
        while (dirent *entry = readdir(dir))
            if (entry != NULL) {
                hook = true;
                break;
            }

        closedir(dir);
    }

    if (hook)
        MSHookFunction(reinterpret_cast<int (*)(const char *, int, mode_t)>(&open), &$open, &_open);
}
