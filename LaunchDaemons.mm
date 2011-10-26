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

#include "Environment.hpp"
#include "LaunchDaemons.hpp"

// XXX: NO means "failed", false means "unneeded"

static bool MSClearLaunchDaemon(NSString *file) {
    NSMutableDictionary *root([NSMutableDictionary dictionaryWithContentsOfFile:file]);
    if (root == nil)
        return NO;

    NSMutableDictionary *environment([root objectForKey:@"EnvironmentVariables"]);
    if (environment == nil)
        return false;

    NSString *variable([environment objectForKey:@ SubstrateVariable_]);
    if (variable == nil)
        return false;

    NSMutableArray *dylibs([[variable componentsSeparatedByString:@":"] mutableCopy]);
    if (dylibs == nil)
        return NO;

    NSUInteger index([dylibs indexOfObject:@ SubstrateLibrary_]);
    if (index == NSNotFound)
        return false;

    [dylibs removeObject:@ SubstrateLibrary_];

    if ([dylibs count] != 0)
        [environment setObject:[dylibs componentsJoinedByString:@":"] forKey:@ SubstrateVariable_];
    else if ([environment count] == 1)
        [root removeObjectForKey:@"EnvironmentVariables"];
    else
        [environment removeObjectForKey:@ SubstrateVariable_];

    NSString *error;
    NSData *data([NSPropertyListSerialization dataFromPropertyList:root format:NSPropertyListBinaryFormat_v1_0 errorDescription:&error]);
    if (data == nil)
        return NO;

    if (![data writeToFile:file atomically:YES])
        return NO;

    return true;
}

bool MSClearLaunchDaemons() {
    NSError *error;

    NSArray *contents([[NSFileManager defaultManager] contentsOfDirectoryAtPath:@ SubstrateLaunchDaemons_ error:&error]);
    if (contents == nil)
        return NO;

    bool cleared(false);

    // XXX: this should filter to only files
    for (NSString *file in contents)
        cleared |= MSClearLaunchDaemon([@ SubstrateLaunchDaemons_ stringByAppendingPathComponent:file]);

    return cleared;
}
