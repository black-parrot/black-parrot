# Dockerfile References: https://docs.docker.com/engine/reference/builder/

FROM ubuntu:18.04

RUN apt-get update

# This deals with tzdata installation issues, but may not configure your VM timezone correctly.
# There are some potential work-arounds if that turns out to be a problem, but they didn't seem
# to be worth the trouble
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get install -y apt-utils tzdata git vim gettext-base \
        bash autoconf automake autotools-dev curl libmpc-dev libmpfr-dev libgmp-dev gawk \
        build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev \
        wget byacc device-tree-compiler python gtkwave python-yaml pkg-config swig python3-dev

RUN apt-get clean

ARG USER_ID
ARG GROUP_ID

# Only create the group if it doesn't exist
RUN getent group $GROUP_ID || groupadd --gid $GROUP_ID build

# Use --no-log-init to deal with large userids creating giant log files
RUN useradd --no-log-init --uid $USER_ID --gid $GROUP_ID --shell /bin/bash --create-home build

LABEL maintainer="Mike Patnode <mike@mpsharp.com>"

WORKDIR /home/build/black-parrot

ENTRYPOINT ["sleep", "inf"]
