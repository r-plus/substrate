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

#ifndef SUBSTRATE_THREADSPECIFIC_HPP
#define SUBSTRATE_THREADSPECIFIC_HPP

#include <pthread.h>

void *SubstrateGetSpecific(pthread_key_t key);
void SubstrateSetSpecific(pthread_key_t key, void *value);

template <typename Type_>
class ThreadSpecific {
  private:
    pthread_key_t key_;

  public:
    ThreadSpecific() {
        pthread_key_create(&key_, NULL);
    }

    ~ThreadSpecific() {
        pthread_key_delete(key_);
    }

    ThreadSpecific &operator =(Type_ value) {
        SubstrateSetSpecific(key_, reinterpret_cast<void *>(value));
        return *this;
    }

    operator Type_() const {
        return reinterpret_cast<Type_>(SubstrateGetSpecific(key_));
    }
};

#endif//SUBSTRATE_THREADSPECIFIC_HPP
