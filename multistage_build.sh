#!/bin/bash

MONGOOSEIM_DOCKER_DIR="./"
MONGOOSEIM_DOCKER_DIR=$(realpath ${MONGOOSEIM_DOCKER_DIR})
MONGOOSEIM_DIR=$1
DOCKERFILE="Dockerfile.multistage"
DOCKERFILE_PATH="${MONGOOSEIM_DOCKER_DIR}/${DOCKERFILE}"
DOCKERHUB_REPO=${DOCKERHUB_REPO:-"mongooseim/mongooseim"}

# Function used for cleanup.
function remove_copied_files() {
    rm -rf $MONGOOSEIM_DIR/member $MONGOOSEIM_DIR/$DOCKERFILE
}

# Check if path to MongooseIM directory was given
if [ $# -ne 1 ]; then
    echo "Usage: ${0} <mongooseim directory>"
    exit 1
fi

# Check if Dockerfile exists
if [ ! -e "$DOCKERFILE" ]; then
    echo "Dockerfile not found at: ${DOCKERFILE}"
    exit 1
fi

# Check if passed MongooseIM directory exists
if [ ! -d "$MONGOOSEIM_DIR" ]; then
    echo "There is no such directory: ${MONGOOSEIM_DIR}"
    exit 1
else
    MONGOOSEIM_DIR=$(realpath ${MONGOOSEIM_DIR})
fi

cd $MONGOOSEIM_DIR

# We assume MongooseIM directory is git repository. Get current ref and version
GIT_REF=`git rev-parse --short HEAD`
VERSION=$(tools/generate_vsn.sh)

# If image tag is not provided with env variable, template it out
# branch and git ref
if [ -z "$IMAGE_TAG" ]; then
    GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    IMAGE_TAG="mongooseim/mongooseim:${GIT_BRANCH}-${GIT_REF}"
fi

#T rap CTRL+C, to remove files when user interupts build process
trap remove_copied_files INT

# Copy files which are required by Dockerfile, fail if coping is not succesed
set -e
cp -ir $MONGOOSEIM_DOCKER_DIR/member $MONGOOSEIM_DIR
cp -i $DOCKERFILE_PATH $MONGOOSEIM_DIR/$DOCKERFILE
set +e

docker build -f "${MONGOOSEIM_DIR}/${DOCKERFILE}" \
    -t $IMAGE_TAG \
    --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg VCS_REF=${GIT_REF} \
    --build-arg VERSION=${VERSION} \
    $MONGOOSEIM_DIR

remove_copied_files
