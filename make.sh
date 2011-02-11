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

PATH=${0%/*}:${PATH}

set -e

ios=-i2.0
mac=-m10.5

declare -a flags
flags+=(-O2 -g0)

flags+=(-isystem extra)
flags+=(-fno-exceptions)
flags+=(-fvisibility=hidden)

declare -a mflags
mflags+=(-Xarch_i386 -fobjc-gc)
mflags+=(-Xarch_x86_64 -fobjc-gc)

function cycc() {
    ./cycc -r4.0 "$@"
    echo
}

flags+=($(cycc "${ios}" "${mac}" -q -V -- -print-prog-name=cc1obj | while read -r arch cc1obj; do
    # XXX: cycc has this crazy newline
    if [[ -n "${arch}" ]]; then
        struct=Struct.${arch}.hpp
        "${cc1obj}" -print-objc-runtime-info </dev/null >"${struct}"
        echo "-Xarch_${arch} -DSTRUCT_HPP=\"${struct}\""
    fi
done))

cycc "${ios}" "${mac}" -oObjectiveC.o -- -c "${flags[@]}" "${mflags[@]}" ObjectiveC.mm

cycc "${ios}" "${mac}" -olibsubstrate.dylib -- "${flags[@]}" -dynamiclib MachMemory.cpp Hooker.cpp ObjectiveC.o nlist.cpp hde64c/src/hde64.c Debug.cpp \
    -framework CoreFoundation \
    -install_name /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate \
    -undefined dynamic_lookup \
    -Ihde64c/include

cycc "${ios}" "${mac}" -oSubstrateBootstrap.dylib -- "${flags[@]}" -dynamiclib Bootstrap.cpp

cycc "${ios}" "${mac}" -oSubstrateLoader.dylib -- "${flags[@]}" -dynamiclib Loader.cpp \
    -framework CoreFoundation

cycc "${ios}" -oMobileSafety.dylib -- "${flags[@]}" -dynamiclib MobileSafety.mm \
    -framework CoreFoundation -framework Foundation -framework UIKit \
    -L. -lsubstrate -lobjc

for name in extrainst_ postrm; do
    cycc "${ios}" -o"${name}" -- "${name}".m "${flags[@]}" \
        -framework CoreFoundation -framework Foundation
done

for arch in i386 arm; do
    ./package.sh "${arch}"
done

echo
PATH=/Library/Cydia/bin:/usr/sbin:/usr/bin:/sbin:/bin sudo dpkg -i com.cydia.substrate_"$(./version.sh)"_cydia.deb
