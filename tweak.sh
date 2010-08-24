#!/bin/bash

function array() { eval "
    declare -a $1

    function $1.+=() {
        while [[ \$# != 0 ]]; do
            $1[\${#$1[@]}]=\$1
            shift 1
        done
    }
"; }

shopt -s nullglob

code=$1

name=$(basename "${code}" .mm)

ios=3.2

archs=(i386 x86_64)
array flags

if [[ -n ${ios} ]]; then
    gcc=/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/g++

    array armv6
    armv6.+= -mcpu=arm1176jzf-s
    armv6.+= -miphoneos-version-min="${ios}"
    armv6.+= -isysroot /Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS"${ios}".sdk
    armv6.+= -idirafter /usr/include

    armv6.+= -F/Library/Frameworks

    archs[${#archs[@]}]=armv6
    for flag in "${armv6[@]}"; do
        flags.+= -Xarch_armv6 "${flag}" 
    done
else
    gcc=g++
fi

array extra
for arch in "${archs[@]}"; do
    while IFS= read -r line; do
        for flag in ${line#%flag *}; do
            extra.+= "-Xarch_${arch}" "${flag}"
        done
    done < <("${gcc}" -arch "${arch}" "${flags[@]}" -E "${code}" | grep '^%flag ')
done

flags.+= "${extra[@]}"
flags.+= -framework CydiaSubstrate
flags.+= -dynamiclib

function lower() {
    tr '[:upper:]' '[:lower:]'
}

# XXX: this should ready some config file
developer='Jay Freeman (saurik) <saurik@saurik.com>'
namespace="com.saurik"

substrate=mobilesubstrate

function filter() {
    sed -e '
        /^'"$1"' / {
            s/^'"$1"' *//;
            p;
        };
    d;' "${code}"
}

function control() {
    unset apt_architecture
    unset apt_author
    unset apt_depends
    unset apt_maintainer
    unset apt_package
    unset apt_priority
    unset apt_section
    unset apt_version

    while IFS= read -r line; do
        if [[ ${line} =~ ^%apt\ *([a-zA-Z_]*)\ *:\ *(.*) ]]; then
            field=${BASH_REMATCH[1]}
            field=$(lower <<<${field})

            value=${BASH_REMATCH[2]}
            if [[ ${field} == depends && ${value} != *${substrate}* ]]; then
                value="${value}, ${substrate}"
            fi

            echo "${field}: ${value}"
            # XXX: escaping is wrong
            eval "apt_${field}='${value}'"
        fi
    done <"${code}"

    if [[ -z ${apt_architecture} && -n ${architecture} ]]; then
        echo "architecture: ${architecture}"
    fi

    if [[ -z ${apt_author} && -n ${developer} ]]; then
        echo "author: ${developer}"
    fi

    if [[ -z ${apt_depends} && -n ${substrate} ]]; then
        echo "depends: ${substrate}"
    fi

    if [[ -z ${apt_maintainer} && -n ${developer} ]]; then
        echo "maintainer: ${developer}"
    fi

    if [[ -z ${apt_package} && -n ${namespace} ]]; then
        echo "package: ${namespace}.$(lower <<<${name})"
    fi

    if [[ -z ${apt_priority} ]]; then
        echo "priority: optional"
    fi

    if [[ -z ${apt_section} ]]; then
        echo "section: Tweaks"
    fi

    if [[ -z ${apt_version} ]]; then
        echo "version: 0.9-1"
    fi
}

function process() {
    cat <<EOF
#line 1 "${code}"
EOF

    sed -e '
        /^%function / {
            s/^%function \(.*[^a-zA-Z_]\)\([a-zA-Z_]*\)(/MSHook(\1, \2, /;
        };
        s/%original/MSOldCall/g;
        /^%/ s/^.*//;
    ' "${code}"
}

function barrier() {
    echo '=================================================='
}

process | grep -v '^$'
barrier
control
barrier
echo g++ "${flags[@]}"
barrier

flags.+= -x objective-c++

temp=$(mktemp ".${name}.XXX")
array temps
temps.+= "${temp}"

post=${temp}.mm
process >"${post}"
temps.+= "${post}"

function clean() {
    rm -rf "${temps[@]}"
    temps=()
}

function try() {
    echo "$@"
    "$@"
    exit=$?
    if [[ ${exit} != 0 ]]; then
        clean
        exit "${exit}"
    fi
}

array thins
for arch in "${archs[@]}"; do
    thin="${temp}.${arch}.dylib"
    thins.+= "${thin}"

    echo "::: -arch ${arch}"
    try "${gcc}" -arch "${arch}" "${flags[@]}" "${post}" -o "${thin}"
    temps.+= "${thin}"

    if [[ ${arch} == arm* ]]; then
        ldid -S "${thin}"
    fi
done

try lipo -create "${thins[@]}" -output "${name}.dylib"

function field() {
    sed -e '
        /^'"$1"' *:/ {
            s/^[^:]*: *//;
            p;
        };
    d;' "${control}"
}

host=$(dpkg-architecture -qDEB_HOST_ARCH 2>/dev/null)

function package() {
    substrate=$1
    architecture=$2

    rm -rf "${temp}"/*

    mkdir -p "${temp}"/DEBIAN
    control="${temp}/DEBIAN/control"
    control >"${control}"

    target=${temp}/Library/MobileSubstrate/DynamicLibraries
    mkdir -p "${target}"
    cp -a "${name}.dylib" "${target}"

    {
        echo -n "Filter = {Bundles = ("
        comma=
        for bundle in $(filter %filter); do
            echo -n "${comma}\"${bundle}\""
            comma=", "
        done
        echo ");};"
    } >"${target}/${name}.plist"

    package=$(field package)
    version=$(field version)

    deb=${package}_${version}_${architecture}.deb
    dpkg-deb -b "${temp}" "${deb}" 2>/dev/null

    if [[ ${architecture} == ${host} ]]; then
        sudo dpkg -i "${deb}"
    fi
}

temp=$(mktemp -d ".${name}.XXX")
temps.+= "${temp}"

package mobilesubstrate iphoneos-arm
package cydiasubstrate darwin-i386

clean
