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

arch=$1
shift 1

pkg=package.${arch}
sudo rm -rf "${pkg}"

mkdir -p "${pkg}"/DEBIAN
control=${pkg}/DEBIAN/control
cat control."${arch}" >"${control}"
./control.sh >>"${control}"

lib=/Library/MobileSubstrate
mkdir -p "${pkg}/${lib}/DynamicLibraries"

fwk=/Library/Frameworks/CydiaSubstrate.framework

if [[ ${arch} == arm ]]; then
    rsc=${fwk}
else
    rsc=${fwk}/Resources
fi

mkdir -p "${pkg}/${rsc}"

for sub in Commands Headers Libraries; do
    mkdir -p "${pkg}/${fwk}/${sub}"
done

cp -a Info.plist "${pkg}/${rsc}/Info.plist"
cp -a CydiaSubstrate.h "${pkg}/${fwk}/Headers"

cp -a SubstrateBootstrap.dylib "${pkg}/${fwk}/Libraries"
cp -a SubstrateLauncher.dylib "${pkg}/${fwk}/Libraries"
cp -a SubstrateLoader.dylib "${pkg}/${fwk}/Libraries"

cp -a libsubstrate.dylib "${pkg}/${fwk}/CydiaSubstrate"

mkdir -p "${pkg}/usr/lib"
ln -s libsubstrate.0.dylib "${pkg}/usr/lib/libsubstrate.dylib"
ln -s "${fwk}/CydiaSubstrate" "${pkg}/usr/lib/libsubstrate.0.dylib"

mkdir -p "${pkg}/usr/include"
ln -s "${fwk}/Headers/CydiaSubstrate.h" "${pkg}/usr/include/substrate.h"

mkdir -p "${pkg}/usr/bin"

for cmd in cycc cynject; do
    ln -s "${fwk}/Commands/${cmd}" "${pkg}/usr/bin"
    cp -a "${cmd}" "${pkg}/${fwk}/Commands"
done

if [[ ${arch} == arm ]]; then
    cp -a extrainst_ postrm "${pkg}/DEBIAN"

    ln -s "${fwk}"/Libraries/SubstrateInjection.dylib "${pkg}/${lib}/MobileSubstrate.dylib"

    ln -s SubstrateBootstrap.dylib "${pkg}/${fwk}/Libraries/SubstrateInjection.dylib"
else
    ln -s SubstrateLoader.dylib "${pkg}/${fwk}/Libraries/SubstrateInjection.dylib"
fi

function field() {
    grep ^"$1": "${control}" | cut -d ' ' -f 2
}

sudo chown -R root:staff "${pkg}"

sudo chgrp procmod "${fwk}/Commands/cynject"
sudo chmod g+s "${fwk}/Commands/cynject"

#(cd "${pkg}" && find . -type f -o -type l)
dpkg-deb -b "${pkg}" "$(field Package)_$(field Version)_$(field Architecture).deb"
