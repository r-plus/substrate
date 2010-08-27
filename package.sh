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

set -e

arch=$1
shift 1

pkg=package.${arch}
sudo rm -rf "${pkg}"

mkdir -p "${pkg}"/DEBIAN
control=${pkg}/DEBIAN/control
cat control."${arch}" control >"${control}"

lib=/Library/MobileSubstrate
mkdir -p "${pkg}/${lib}/DynamicLibraries"

fwk=/Library/Frameworks/CydiaSubstrate.framework
cur=${fwk}/Versions/Current
ver=${fwk}/Versions/0

mkdir -p "${pkg}/${ver}/Resources"
ln -s 0 "${pkg}/${cur}"

for sub in Commands Headers Libraries Resources; do
    mkdir -p "${pkg}/${ver}/${sub}"
    ln -s "Versions/Current/${sub}" "${pkg}/${fwk}"
done

cp -a Info.plist "${pkg}/${ver}/Resources/Info.plist"
cp -a CydiaSubstrate.h "${pkg}/${ver}/Headers"

cp -a MobileSubstrate.dylib "${pkg}/${fwk}"
cp -a MobileLoader.dylib "${pkg}/${fwk}"

cp -a libsubstrate.dylib "${pkg}/${ver}/CydiaSubstrate"
ln -s "Versions/Current/CydiaSubstrate" "${pkg}/${fwk}"

mkdir -p "${pkg}/usr/lib"
ln -s libsubstrate.0.dylib "${pkg}/usr/lib/libsubstrate.dylib"
ln -s "${ver}/CydiaSubstrate" "${pkg}/usr/lib/libsubstrate.0.dylib"

mkdir -p "${pkg}/usr/include"
ln -s "${fwk}/Headers/CydiaSubstrate.h" "${pkg}/usr/include/substrate.h"

mkdir -p "${pkg}/usr/bin"
ln -s "${cur}/Commands/cycc" "${pkg}/usr/bin"
cp -a cycc "${pkg}/${cur}/Commands"

if [[ ${arch} == arm ]]; then
    cp -a extrainst_ postrm "${pkg}/DEBIAN"

    cp -a MobileSafety.dylib "${pkg}/${fwk}"
    cp -a MobileSafety.png "${pkg}/${fwk}"

    ln -s "${fwk}"/MobileSubstrate.dylib "${pkg}/${lib}/MobileSubstrate.dylib"
fi

function field() {
    grep ^"$1": "${control}" | cut -d ' ' -f 2
}

sudo chown -R root:staff "${pkg}"
(cd "${pkg}" && find . -type f -o -type l)
dpkg-deb -b "${pkg}" "$(field Package)_$(field Version)_$(field Architecture).deb" #2>/dev/null
