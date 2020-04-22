# Dockerfile References: https://docs.docker.com/engine/reference/builder/

FROM ubuntu:18.04

RUN apt-get update

RUN DEBIAN_FRONTEND="noninteractive" apt-get install -y apt-utils tzdata git vim

RUN apt-get install -y bash autoconf automake autotools-dev curl libmpc-dev libmpfr-dev libgmp-dev gawk

RUN apt-get install -y build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev

RUN apt-get install -y wget byacc device-tree-compiler python gtkwave python-yaml pkg-config swig python3-dev

RUN apt-get clean

ARG USER_ID
ARG GROUP_ID

RUN getent group $GROUP_ID || groupadd --gid $GROUP_ID build

# Use --no-log-init to deal with large userids creating giant log files
RUN useradd --no-log-init --uid $USER_ID --gid $GROUP_ID --shell /bin/bash --create-home build

LABEL maintainer="Mike Patnode <mike@mpsharp.com>"

# Set the Current Working Directory inside the container
WORKDIR /home/build/black-parrot

# Build the emulator and tests
# RUN  cd /black-parrot && make prep_lite

ENTRYPOINT ["sleep", "inf"]
