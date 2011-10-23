#!/bin/bash

# Cydia Substrate - Powerful Code Insertion Platform
# Copyright (C) 2008-2011  Jay Freeman (saurik)

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

set -e

shopt -s extglob

hpp=$1
object=$2
name=$3
sed=$4
otool=$5
lipo=$6
nm=$7
shift 7

#shift 1
#set /Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/gcc-4.2 -I/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS3.1.3.sdk/usr/include "$@"

"$@"

detailed=$("${lipo}" -detailed_info "${object}")

{

echo '#include "Trampoline.hpp"'

for arch in $(echo "${detailed}" | "${sed}" -e '/^architecture / { s/^architecture //; p; }; d;'); do
    offset=$(echo "${detailed}" | "${sed}" -e '
        /^architecture / { x; s/.*/0/; x; };
        /^architecture '${arch}'$/ { x; s/.*/1/; x; };
        x; /^1$/ { x; /^ *offset / { s/^ *offset //; p; }; x; }; x;
        d;
    ')

    file=($("${otool}" -arch "${arch}" -l "${object}" | "${sed}" -e '
        x; /^1$/ { x;
            /^ *fileoff / { s/^.* //; p; };
            /^ *filesize / { s/^.* //; p; };
        x; }; x;

        /^ *cmd LC_SEGMENT/ { x; s/.*/1/; x; };

        d;
    '))

    fileoff=${file[0]}
    filesize=${file[1]}

    echo
    echo "static const char ${name}_${arch}_data_[] = {"

    od -v -t x1 -t c -j "$((offset + fileoff))" -N "${filesize}" "${object}" | "${sed}" -e '
        /^[0-7]/ ! {
            s@^        @//  @;
            s/\(....\)/ \1/g;
            s@^ // @//@;
            s/ *$/,/;
        };

        /^[0-7]/ {
            s/^[^ ]*//;
            s/  */ /g;
            s/^ *//;
            s/ $//;
            s/ /,/g;
            s/\([^,][^,]\)/0x\1/g;
            s/$/,/;
            /^,$/ ! { s/^/    /g; p; }; d;
        };
    '

    echo "};"

    echo
    entry=$("${nm}" -arch "${arch}" "${object}" | "${sed}" -e '/ _Start$/ { s/ .*//; p; }; d;')
    entry=${entry##*(0)}
    echo "static size_t ${name}_${arch}_entry_ = 0x${entry:=0};"

    echo
    echo "/*"
    "${otool}" -vVt -arch "${arch}" "${object}"
    echo "*/"

    echo
    echo "static Trampoline ${name}_${arch}_ = {"
    echo "    ${name}_${arch}_data_,"
    echo "    sizeof(${name}_${arch}_data_),"
    echo "    ${name}_${arch}_entry_,"
    echo "};"
done

} >"${hpp}"

#rm -f "${object}"
