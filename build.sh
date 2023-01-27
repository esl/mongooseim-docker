#!/usr/bin/env bash

set -e
cd "$( dirname "${BASH_SOURCE[0]}" )"

# Build a builder image (contains erlang and the build tools)
docker build -f Dockerfile.builder -t mongooseim-builder .

# Create a volume for the result tarballs
docker volume create mongooseim-builds || echo "Probably already created volume"

# Build MongooseIM release
docker run --rm -v mongooseim-builds:/builds -e TARBALL_NAME=mongooseim.tar.gz mongooseim-builder /build.sh

# Copy our build artifact
CID=$(docker run --rm -d -v mongooseim-builds:/builds busybox sleep 1000)
docker cp $CID:/builds/mongooseim.tar.gz ./member/
docker rm -f $CID

# Build a final image
docker build -f Dockerfile.member -t mongooseim .
