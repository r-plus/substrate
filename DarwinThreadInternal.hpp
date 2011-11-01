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

#ifndef SUBSTRATE_DARWINTHREADINTERNAL_HPP
#define SUBSTRATE_DARWINTHREADINTERNAL_HPP


// forces _pthread_setspecific_direct() to not call pthread_setspecific()
// this is required to use thread local storage in trampolines and hooks
// we save the old value here so we can restore it later in this file

#ifndef __OPTIMIZE__
#define MSNoOptimize
#define __OPTIMIZE__
#endif


#include <pthread_internals.h>


// we will now restore the original value of __OPTIMIZE__, for other code

#ifdef MSNoOptimize
#undef MSNoOptimize
#undef __OPTIMIZE__
#endif

#endif//SUBSTRATE_DARWINTHREADINTERNAL_HPP
