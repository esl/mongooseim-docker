#!/bin/bash

[ x"${MONGOOSEIM_DIR}" == x"" ] && echo "MONGOOSEIM_DIR not set!" && exit 1

NODE=mongooseim@${HOSTNAME}
NODETYPE=sname:${NODE}
CLUSTER_NODE=mongooseim@mim-1
CLUSTER_COOKIE=ejabberd
MNESIA_DIR=${MONGOOSEIM_DIR}/mnesia

# clusterize?
if [ x"mim-1" = x"${HOSTNAME}" ]; then
    echo "MongooseIM cluster primary node: ${NODE}"
elif [ ! -f "${MNESIA_DIR}/schema.DAT" ]; then
    # epmd must be running for escript to use distribution
    epmd -daemon
    escript /clusterize ${NODETYPE} ${CLUSTER_COOKIE} ${CLUSTER_NODE} ${MNESIA_DIR} && \
        echo "Clustered ${NODE} with ${CLUSTER_NODE}" || \
        echo "Failed clustering ${NODE} with ${CLUSTER_NODE}"
fi

mongooseimctl start
mongooseimctl started
bash
