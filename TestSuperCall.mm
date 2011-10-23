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

struct dat {
    uint32_t a;
    uint32_t b;
    uint32_t c;
    uint32_t d;
    uint32_t e;
    uint32_t f;
    uint32_t g;
    uint32_t h;
};

@interface A : NSObject
- (int) testI;
- (dat) testS;
@end

@implementation A

- (int) testI {
    return 0x31337;
}

- (dat) testS {
    dat value = { 0x31337 };
    return value;
}

@end

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

MSInstanceMessageHook0(int, B, testI) {
    return MSOldCall() - 0x31337 + 0xae5bda7a;
}

MSInstanceMessageHook0(dat, B, testS) {
    dat value = { MSOldCall().a - 0x31337 + 0xae5bda7a };
    return value;
}

int main() {
    B *b([[B alloc] init]);
    printf("0x%x\n", [b testI]);
    printf("0x%x\n", [b testS].a);
    return 0;
}
