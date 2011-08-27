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
#include "CydiaSubstrate.h"

@interface A : NSObject
- (int) test;
@end

@implementation A
- (int) test {
    return 0x31337;
} @end

@interface B : A
@end

@implementation B
@end

extern "C" bool MSDebug;

struct Debug {
Debug() {
    MSDebug = true;
} } debug_;

MSClassHook(B)

MSInstanceMessageHook0(int, B, test) {
    return MSOldCall() - 0x31337 + 0xae5bda7a;
}

int main() {
    B *b([[B alloc] init]);
    printf("0x%x\n", [b test]);
    return 0;
}
