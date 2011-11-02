#!/bin/bash

set -e
set -o pipefail

user=$1
header=$2
defs=$3

mig -arch i386 -server /dev/null -user /dev/stdout -header "${header}" "${defs}" | sed -e $'
    /^mig_external kern_return_t / {
        n;
        n;
        x;
        s/.*/\tmach_port_t reply_port,/;
        p;
        x;
    };
' >"${user}" || rm -f "${user}"
