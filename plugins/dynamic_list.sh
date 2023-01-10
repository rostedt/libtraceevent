#!/bin/sh
# SPDX-License-Identifier: LGPL-2.1

symbol_type=$(nm -u -D $@ | awk 'NF>1 {print $1}' | xargs echo "U w W" |
              tr 'w ' 'W\n' | sort -u | xargs echo)

if [ "$symbol_type" = "U W" ]; then
    echo '{'
    nm -u -D $@ | awk 'NF>1 {sub("@.*", "", $2); print "\t"$2";"}' | sort -u
    echo '};'
fi
