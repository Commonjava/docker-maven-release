#!/bin/bash

# Assume this script is in the scripts/ or private/ directory, then 
# figure out where the private directory is based on that.
#
# NOTE: If you're using a different location than private/ to
# store private files for use in this container, you'll need
# to modify this script.
SCRIPT_DIR=$(dirname $(readlink -f "$0"))
PRIVATE_DIR=$(dirname $SCRIPT_DIR)/private

# If you use Docker with firewalld, you may have to specify
# some specific configuration to allow this port to be
# accessible from within a Docker container.
#
# Also, this IP address is on the $DOCKER_NET specified
# below.
DOCKER_HOST="tcp://172.18.0.1:2375"

# We may need a special docker network (bridge-mode so
# your containers can still see the outside world). This
# lets containers communicate with one another, which from
# what I can tell isn't allowed with the normal docker0
# bridge.
DOCKER_NET=${DOCKER_NET:-ci-network}

$SCRIPT_DIR/trust-docker-net.sh

set -x

GIT="$1"
shift

BRANCH="master"
if [ "x${1}" != "x" ]; then
    BRANCH="$1"
    shift
fi

name=$(basename $GIT)-${BRANCH}-$(date '+%s')

docker run -ti \
           --name $name \
           -v $PRIVATE_DIR/m2:/home/maven/.m2 \
           -v $PRIVATE_DIR/ssh:/home/maven/.ssh \
           -v $PRIVATE_DIR/gnupg:/home/maven/.gnupg \
           -v $PRIVATE_DIR/gitconf:/home/maven/gitconf \
           --network $DOCKER_NET \
           -e GIT="$GIT" \
           -e GIT_BRANCH="$BRANCH" \
           -e DOCKER_HOST=$DOCKER_HOST \
           docker.io/commonjava/maven-release -B "$@"
