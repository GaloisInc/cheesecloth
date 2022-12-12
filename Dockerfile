# docker build -f Dockerfile -t cheesecloth-image .
# docker run -it cheesecloth-image:latest  /bin/bash
# ./scripts/run_grit

# It might be useful to volume mount the directory where is generated the large sieveir circuit files
# docker run -v <PATH_HOST>:/root/cheesecloth/out/ -it cheesecloth-image:latest  /bin/bash

FROM debian:stable

RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y \
    build-essential \
    curl \
    net-tools \
    iputils-ping \
    iproute2
RUN apt-get update

# Get Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"


# # Get clang9 debian
RUN apt-get install -y clang-9

# Get meson
RUN apt-get install -y meson

# Get cmake
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -y install cmake


RUN apt-get install -y git texinfo
RUN apt-get install -y python-setuptools-doc python3-distutils python3-lib2to3 python3-setuptools

# Install stack
RUN curl -sSL https://get.haskellstack.org/ | /bin/sh
ENV PATH="/root/.local/bin:${PATH}"
RUN apt-get install time

COPY . /root/cheesecloth
WORKDIR /root/cheesecloth

RUN ./scripts/build_grit
RUN ./scripts/build_microram
RUN ./scripts/build_witness_checker

RUN mkdir -p /root/cheesecloth/out
# we dont want to do that when building because the sieveir files are too large
# RUN ./scripts/run_grit
