#!/bin/bash

# Cydia Substrate - Powerful Code Insertion Platform
# Copyright (C) 2008-2010  Jay Freeman (saurik)

# GNU Lesser General Public License, Version 3 {{{
#
# Substrate is free software: you can redistribute it and/or modify it under
# the terms of the GNU Lesser General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# Substrate is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
# License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with Substrate.  If not, see <http://www.gnu.org/licenses/>.
# }}}

while read -r arch cc1obj; do
    # XXX: cycc has this crazy newline
    if [[ -n "${arch}" ]]; then
        struct=Struct.${arch}.hpp
        "${cc1obj}" -print-objc-runtime-info </dev/null >"${struct}"
        echo "-Xarch_${arch} -DSTRUCT_HPP='\"${struct}\"'"
    fi
done
