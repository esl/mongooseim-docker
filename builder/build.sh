#!/usr/bin/env bash

#set -x

# /builds is assumed to be a shared volume

BUILDS=${BUILDS:-/builds}
SPECS=$BUILDS/specs
LOGFILE=${LOGFILE:-$BUILDS/logs/build.log}
TIMESTAMP=$(date +%F_%H%M%S)
mkdir -p "$(dirname $LOGFILE)" || exit 1

log () {
    echo $@ > $LOGFILE
}

build () {
    local name=$1
    local commit=$2
    local repo=$3
    local build_script=$4
    if [ ! x"" = x"$4" ]; then
        $BUILDS/$build_script $name $commit $repo
    else
        do_build $name $commit $repo
    fi
}

do_build () {
    touch ${name}-${commit}-${repo}.fake
    echo do_build: $name $commit $repo
}

while read specline; do
    build $specline
done < $SPECS

#TARGET_TGZ=mongooseim.${TIMESTAMP}.tar.gz
#git clone $MONGOOSEIM_REPO -b $MONGOOSEIM_VERSION $MONGOOSEIM_DIR && \
#    cd $MONGOOSEIM_DIR && \
#    make local && \
#    cd rel && \
#    echo $MONGOOSEIM_VERSION > mongooseim/version && \
#    git describe --always >> mongooseim/version && \
#    tar cvfzh /data/$TARGET_TGZ mongooseim

#cd /data
#if [ -L mongooseim.tar.gz ]; then
#    rm mongooseim.tar.gz
#fi
#ln -s $TARGET_TGZ mongooseim.tar.gz
