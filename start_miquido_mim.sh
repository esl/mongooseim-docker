#!/bin/bash

IMAGE_TAG=miquido_mim 
POSTGRES_NAME=miquido_postgres
POSTGRES_USER=mongooseIM
POSTGRES_PASSWORD=mongooseim
DB_NAME=mongooseim

set -e

ensure_container_removed(){
    docker stop $1 || true
    docker rm $1 || true
}

# Build mongoose's image from repo under path given
# as first argument
IMAGE_TAG=$IMAGE_TAG ./multistage_build.sh $1

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
docker exec $POSTGRES_NAME psql -U $POSTGRES_USER $DB_NAME < $(realpath "$1/priv/pg.sql")

CONFIG_PATH=$(realpath ./config)
docker run --hostname miquido_mim-1 --network miquido_mim -p 5222:5222 -v $CONFIG_PATH:/member/ $IMAGE_TAG
