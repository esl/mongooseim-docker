#!/usr/bin/env bash

#set -x

NODE=mongooseim@${HOSTNAME}
NODETYPE=sname:${NODE}
CLUSTER_NODE=mongooseim@${HOSTNAME%-?}-1
CLUSTER_COOKIE=ejabberd
MNESIA_DIR=/member/mongooseim/Mnesia.${NODE}

cd /member
tar xfz mongooseim.tar.gz || (echo "can't untar release" && exit 1)
[ -f /member/hosts ] && cat /member/hosts >> /etc/hosts
cd -

echo "hosts:"
cat /etc/hosts

# make sure proper node name is used
echo "vm.args:"
sed -i -e "s/-sname.*$/-sname ${NODE}/" /member/mongooseim/etc/vm.args
cat /member/mongooseim/etc/vm.args

#file "${MNESIA_DIR}/schema.DAT"

CLUSTERING_RESULT=0
# clusterize? if the numeric nodename suffix is 1 we are the master
if [ x"${HOSTNAME##*-}" = x"1" ]; then
    echo "MongooseIM cluster primary node ${NODE}"
elif [ ! -f "${MNESIA_DIR}/schema.DAT" ]; then
    echo "MongooseIM node ${NODE} joining ${CLUSTER_NODE}"
    # epmd must be running for escript to use distribution
    epmd -daemon
    escript /clusterize ${NODETYPE} ${CLUSTER_COOKIE} ${CLUSTER_NODE} ${MNESIA_DIR}
    CLUSTERING_RESULT=$?
else
    echo "MongooseIM node ${NODE} already clustered"
fi

if [ ${CLUSTERING_RESULT} == 0 ]; then
    echo "Clustered ${NODE} with ${CLUSTER_NODE}"
    PATH="/member/mongooseim/bin:${PATH}"
    if [ "$#" -ne 1 ]; then
        mongooseim live --noshell -noinput +Bd  -mnesia dir \"${MNESIA_DIR}\"
    else
        mongooseimctl $1
    fi
else
    echo "Failed clustering ${NODE} with ${CLUSTER_NODE}"
    exit 2
fi
