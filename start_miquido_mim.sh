#!/bin/bash

IMAGE_TAG=miquido_mim 
POSTGRES_NAME=miquido_postgres
POSTGRES_USER=mongooseIM
POSTGRES_PASSWORD=mongooseim
DB_NAME=mongooseim
CONFIG_PATH=$(realpath ./config)

set -e

show_usage(){
    echo "Usage"
    echo "If you want to rebuild the image:"
    echo "sudo ${0} build <path_to_mim_repo>"
    echo "or"
    echo "If you want to run docker cotainers from existing image"
    echo "sudo ${0} run <path_to_mim_repo>"
}

if [[ $# != 2 ]] || [[ $1 != "run" && $1 != "build" ]]; then
    show_usage
    exit 1
fi

MIM_REPO_PATH=$2

ensure_container_removed(){
    docker stop $1 || true
    docker rm $1 || true
}

if [ $1 = "build" ]; then
    # Build mongoose's image from repo under path given
    # as first argument
    IMAGE_TAG=$IMAGE_TAG ./multistage_build.sh $MIM_REPO_PATH
    exit 0
fi

# Else it's "run"
docker network create --driver bridge miquido_mim || true

ensure_container_removed miquido_postgres
ensure_container_removed miquido_mim

docker run \
    --name $POSTGRES_NAME \
    --network miquido_mim \
    -e POSTGRES_USER=$POSTGRES_USER \
    -e POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
    -d postgres
echo "Waiting for postgres" && sleep 5 # we wait for db to start
docker exec $POSTGRES_NAME psql -U $POSTGRES_USER -c "CREATE DATABASE $DB_NAME;"
docker exec $POSTGRES_NAME psql -U $POSTGRES_USER $DB_NAME < $(realpath "$MIM_REPO_PATH/priv/pg.sql")

docker run --hostname miquido_mim-1 --network miquido_mim -p 443:443 -v $CONFIG_PATH:/member/ $IMAGE_TAG
