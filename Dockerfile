# docker build --platform linux/x86_64 -f cheesecloth/Dockerfile -t cheesecloth-image .
# docker run --platform linux/x86_64 -it cheesecloth-image:latest  /bin/bash
# ./scripts/run_grit

# It might be useful to volume mount the directory where is generated the large sieveir circuit files
# docker run -v <PATH_HOST>:/root/cheesecloth/out/ -it cheesecloth-image:latest  /bin/bash

FROM ubuntu:16.04

RUN apt-get update
RUN apt-get upgrade -y
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get install -y \
    build-essential \
    curl \
    net-tools \
    iputils-ping \
    iproute2 \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    cmake \
    less \
    vim \
    wget
RUN apt-add-repository universe
RUN apt-get update

# Get meson
RUN apt-get install -y meson

RUN apt-get install -y git texinfo
RUN apt-get install -y python-setuptools-doc python-distutils-extra python3-pip python3-setuptools

# Install clang9 debian
RUN wget https://github.com/llvm/llvm-project/releases/download/llvmorg-9.0.1/clang+llvm-9.0.1-x86_64-linux-gnu-ubuntu-16.04.tar.xz
RUN tar -xf clang+llvm-9.0.1-x86_64-linux-gnu-ubuntu-16.04.tar.xz
RUN mv clang+llvm-9.0.1-x86_64-linux-gnu-ubuntu-16.04 /usr/local/clang9
ENV PATH="/usr/local/clang9/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/clang9/lib:${LD_LIBRARY_PATH}"

# Get Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Install stack
RUN curl -sSL https://get.haskellstack.org/ | /bin/sh
ENV PATH="/root/.local/bin:${PATH}"
RUN apt-get install time

COPY swanky /root/swanky
COPY cheesecloth /root/cheesecloth
WORKDIR /root/cheesecloth

RUN rustup install 1.69.0-x86_64-unknown-linux-gnu
RUN rustup default 1.69.0-x86_64-unknown-linux-gnu
RUN rm rust-toolchain
RUN ./scripts/build_witness_checker
RUN ./scripts/build_microram

