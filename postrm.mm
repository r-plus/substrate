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

#include <string.h>
#include <stdbool.h>
#include <unistd.h>

#include <Foundation/Foundation.h>

#include <stdlib.h>

#include "Cydia.hpp"
#include "LaunchDaemons.hpp"

int main(int argc, char *argv[]) {
    if (argc < 2 || (
        strcmp(argv[1], "abort-install") != 0 &&
        strcmp(argv[1], "remove") != 0 &&
    true)) return 0;

    NSAutoreleasePool *pool([[NSAutoreleasePool alloc] init]);

    NSFileManager *manager([NSFileManager defaultManager]);
    NSError *error;

    if (NSString *config = [NSString stringWithContentsOfFile:@ SubstrateLaunchConfig_ encoding:NSNonLossyASCIIStringEncoding error:&error]) {
        NSArray *lines([config componentsSeparatedByString:@"\n"]);
        NSMutableArray *copy([lines mutableCopy]);

        [copy removeObject:@""];
        [copy removeObject:@ SubstrateBootstrapExecute_];

        if ([copy count] == 0)
            [manager removeItemAtPath:@ SubstrateLaunchConfig_ error:&error];
        else {
            [copy addObject:@""];

            if (![copy isEqualToArray:lines])
                [[copy componentsJoinedByString:@"\n"] writeToFile:@ SubstrateLaunchConfig_ atomically:YES encoding:NSNonLossyASCIIStringEncoding error:&error];
        }
    }

    if (MSClearLaunchDaemons())
        FinishCydia("reboot");

    [pool release];
    return 0;
}
