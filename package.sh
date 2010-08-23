#!/bin/bash

arch=$1
shift 1

pkg=package.${arch}
rm -rf "${pkg}"

mkdir -p "${pkg}"/DEBIAN
control=${pkg}/DEBIAN/control
cat control."${arch}" control >"${control}"

mkdir -p "${pkg}"/Library/MobileSubstrate/DynamicLibraries

fwk="${pkg}"/Library/Frameworks/CydiaSubstrate.framework
ver="${fwk}"/Versions/A
mkdir -p "${ver}"/Resources
ln -s A "${fwk}"/Versions/Current

for sub in CydiaSubstrate Headers Resources; do
    ln -s Versions/Current/"${sub}" "${fwk}"
done

mkdir -p "${ver}"/Headers
cp -a CydiaSubstrate.h "${ver}"/Headers

cp -a MobileSubstrate.dylib "${fwk}"
cp -a MobileLoader.dylib "${fwk}"

cp -a libsubstrate.dylib "${ver}"/CydiaSubstrate

if [[ ${arch} == arm ]]; then
    cp -a extrainst_ postrm "${pkg}"/DEBIAN

    cp -a MobileSafety.dylib "${fwk}"
    cp -a MobilePaper.png "${fwk}"

    mkdir -p "${pkg}"/usr/lib
    ln -s /Library/Frameworks/CydiaSubstrate.framework/CydiaSubstrate "${pkg}"/usr/lib/libsubstrate.dylib

    mkdir -p "${pkg}"/usr/include
    ln -s /Library/Frameworks/CydiaSubstrate.framework/Headers/CydiaSubstrate.h "${pkg}"/usr/include/substrate.h
fi

function field() {
    grep ^"$1": "${control}" | cut -d ' ' -f 2
}

chown -R root:staff "${pkg}"
dpkg-deb -b "${pkg}" "$(field Package)_$(field Version)_$(field Architecture).deb" 2>/dev/null
