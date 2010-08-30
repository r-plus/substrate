/* Cydia Substrate - Powerful Code Insertion Platform
 * Copyright (C) 2008-2010  Jay Freeman (saurik)
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

#ifndef SUBSTRATE_DEBUG_HPP
#define SUBSTRATE_DEBUG_HPP

#ifdef __APPLE__
#include <CoreFoundation/CFLogUtilities.h>
/* XXX: proper CFStringRef conversion */
#define lprintf(format, ...) \
    CFLog(kCFLogLevelNotice, CFSTR(format), ## __VA_ARGS__)
#else
#define lprintf(format, ...) do { \
    fprintf(stderr, format...); \
    fprintf(stderr, "\n"); \
} while (false)
#endif

extern "C" bool MSDebug;
void MSLogHex(const void *vdata, size_t size, const char *mark = 0);

#endif//SUBSTRATE_DEBUG_HPP
