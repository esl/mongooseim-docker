#!/usr/bin/env bash

#set -x

# /builds is assumed to be a shared volume

BUILDS=${BUILDS:-/builds}
SPECS=$BUILDS/specs
LOGFILE=${LOGFILE:-$BUILDS/build.log}
TIMESTAMP=$(date +%F_%H%M%S)

log () {
    echo \[$(date '+%F %H:%M:%S')\] $@
}

build () {
    local name=$1
    local commit=$2
    local repo=$3
    local build_script=$4
    if [ ! x"" = x"$4" ]; then
        log $build_script: $name $commit $repo | tee -a $LOGFILE
        $BUILDS/$build_script $name $commit $repo | tee -a ${LOGFILE}
    else
        log do_build: $name $commit $repo | tee -a $LOGFILE
        do_build $name $commit $repo | tee -a ${LOGFILE}
    fi
}

do_build () {
    local name=$1
    local commit=$2
    local repo=$3
    local workdir=/tmp/mongooseim
    [ -d $workdir ] && rm -rf $workdir
    git clone $repo $workdir && \
        cd $workdir && \
        git checkout $commit && \
        tools/configure full && \
        make rel && \
        echo "${name}-${commit}-${repo}" > rel/mongooseim/version && \
        git describe --always >> rel/mongooseim/version
    local build_success=$?
    local timestamp=$(date +%F_%H%M%S)
    local tarball="mongooseim-${name}-${commit}-${timestamp}.tar.gz"
    if [ $build_success = 0 ]; then
        cd rel && \
        tar cfzh ${BUILDS}/${tarball} mongooseim && \
        log "${BUILDS}/$tarball is ready" && \
        exit 0
    else
        log "build failed"
        exit 1
    fi
    log "tarball generation failed"
    exit 2
}

while read specline; do
    [ ! -z "$specline" ] && build $specline
done < $SPECS
