#!/bin/bash

src="patches/v1-needs-to-remove-change-id"
dst="patches/v1-internal"

for fs in ${src}/*.patch; do
    fb=$(basename $fs)
    fd="${dst}/${fb}"
    echo "Compare ${fs} and ${fd}"
    diff "${fs}" "${fd}"
    #  | grep -v "Change-Id" | grep -v "index" | grep -v "From" | grep -v "\-\-\-"
done