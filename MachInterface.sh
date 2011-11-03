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
        s/.*/\tmach_msg_id_t msgh_id,/;
        p;
        s/.*/\tmach_port_t reply_port,/;
        p;
        x;
    };

    s/^\\(mig_internal kern_return_t __MIG_check__Reply__[^(]*(\\)/\\1mach_msg_id_t msgh_id, /;
    s/\\(check_result = __MIG_check__Reply__[^(]*(\\)/\\1msgh_id, /;

    s/mig_get_reply_port()/reply_port/g;
    s/31337\\([0-9][0-9]\\)/msgh_id/g;
    s/31338\\([0-9][0-9]\\)/(msgh_id + 100)/g;
' >"${user}" || rm -f "${user}"
