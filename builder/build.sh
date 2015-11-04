#!/usr/bin/env bash

# /builds is assumed to be a shared volume

if [ -d $MONGOOSEIM_DIR ]; then
    rm -rf $MONGOOSEIM_DIR
fi

TIMESTAMP=$(date +%F_%H%M%S)
TARGET_TGZ=mongooseim.${TIMESTAMP}.tar.gz
git clone $MONGOOSEIM_REPO -b $MONGOOSEIM_VERSION $MONGOOSEIM_DIR && \
    cd $MONGOOSEIM_DIR && \
    make local && \
    cd rel && \
    echo $MONGOOSEIM_VERSION > mongooseim/version && \
    git describe --always >> mongooseim/version && \
    tar cvfzh /data/$TARGET_TGZ mongooseim

cd /data
if [ -L mongooseim.tar.gz ]; then
    rm mongooseim.tar.gz
fi
ln -s $TARGET_TGZ mongooseim.tar.gz
