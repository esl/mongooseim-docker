#!/usr/bin/env bash

#set -x
MIM_WORK_DIR="/usr/lib"
tar xfz mongooseim.tar.gz -C ${MIM_WORK_DIR} || (echo "can't untar release" && exit 1)
ls /member
cd /member
[ -f /member/hosts ] && cat /member/hosts >> /etc/hosts
cd -

NODE=mongooseim@${HOSTNAME}
NODETYPE=sname:${NODE}
CLUSTER_COOKIE=mongooseim
ROOT_DIR=${MIM_WORK_DIR}/mongooseim
MNESIA_DIR=/var/lib/mongooseim/Mnesia.${NODE}
LOGS_DIR=/var/log/mongooseim
EPMD=`find ${ROOT_DIR} -name epmd`
ESCRIPT=`find ${ROOT_DIR} -name escript`
ETC_DIR=${ROOT_DIR}/etc

# if there are predefined config files available, use them
FILES=( "/member/mongooseim.cfg" "/member/app.config" "/member/vm.args" "/member/vm.dist.args" )
for file in "${FILES[@]}"
do
    [ -f "${file}" ] && cp "${file}" ${ETC_DIR}/
done

# make sure proper node name is used
echo "vm.args:"
sed -i -e "s/-sname.*$/-sname ${NODE}/" ${ETC_DIR}/vm.args
cat ${ETC_DIR}/vm.args

echo "app.config"
sed -i -e "s,%{mnesia.*,{mnesia\, [{dir\, \"${MNESIA_DIR}\"}]}\,," ${ETC_DIR}/app.config
sed -i -e "s,{log_root.*,{log_root\, \"/var/log/mongooseim\"}\,," ${ETC_DIR}/app.config
cat ${ETC_DIR}/app.config

echo "vm.dist.args"
cat ${ETC_DIR}/vm.dist.args

#file "${MNESIA_DIR}/schema.DAT"

mkdir -p /var/lib/mongooseim
mkdir -p ${LOGS_DIR}

PATH="${MIM_WORK_DIR}/mongooseim/bin:${PATH}"

function run() {
    if [ "$#" -ne 1 ]; then
        mongooseim live --noshell -noinput +Bd
    else
        mongooseimctl $1
    fi
}

DEFAULT_CLUSTERING=0
if [ "${CLUSTER_WITH}" = "" ]; then
    CLUSTER_WITH="mongooseim@${HOSTNAME%-?}-1"
    DEFAULT_CLUSTERING=1
fi

if [ "${JOIN_CLUSTER}" = "" ] || [ "${JOIN_CLUSTER}" = "true"] || [ "${JOIN_CLUSTER}" = "1" ]; then
    CLUSTERING_RESULT=0
    # don't cluster if default clustering is used and out suffix is -1
    if [ $DEFAULT_CLUSTERING -eq 1 ] && [ x"${HOSTNAME##*-}" = x"1" ]; then
        echo "MongooseIM cluster primary node ${NODE}"
    elif [ ! -f "${MNESIA_DIR}/schema.DAT" ]; then
        echo "MongooseIM node ${NODE} joining ${CLUSTER_WITH}"
        mongooseimctl start
        mongooseimctl started
        mongooseimctl status
        mongooseimctl join_cluster -f ${CLUSTER_WITH}
        CLUSTERING_RESULT=$?
        mongooseimctl stop
    else
        echo "MongooseIM node ${NODE} already clustered"
    fi

    if [ ${CLUSTERING_RESULT} == 0 ]; then
        echo "Clustered ${NODE} with ${CLUSTER_WITH}"
        run
    else
        echo "Failed clustering ${NODE} with ${CLUSTER_WITH}"
        exit 2
    fi
else
    run
fi
