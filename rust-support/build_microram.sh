#!/bin/bash
set -xeuo pipefail

support_dir="$(dirname "$0")"

name="$1"

if [[ "$#" -eq 2 ]]; then
    package_dir=$2
else
    package_dir=.
fi

if [[ "$#" -eq 3 ]]; then
    out_name=$3
else
    out_name=$name
fi

features="${features-},microram"

mkdir -p build

# Remove existing bitcode, so that only the most recent bitcode is present
# after cargo finishes the build.
find target -name "$name-*.bc" -delete || true

# Build RISC-V ASM for the victim (server) program:
RUSTC_BOOTSTRAP=1 cargo +1.56.0 rustc \
    --release -Z build-std=core,alloc --target $support_dir/target-rv64.json \
    --manifest-path "$package_dir/Cargo.toml" --locked --bin "$name" \
    --features "$features" -- --emit llvm-bc -Z no-link
# The output filename contains a random hash.  Find it as follows:
bc_path="$(find target -name "$name-*.bc")"
cp "$bc_path" "build/$out_name.bc"

if [ -z "${PICOLIBC_HOME-}" ]; then
    PICOLIBC_HOME="$support_dir/../picolibc/build/image/picolibc/riscv64-unknown-fromager"
fi


case $name in
    secrets)
        # Don't link
        : "${cc_link=0}"
        ;;
esac

: "${cc_link=1}"
: "${cc_secret_objects=build/secrets.bc}"

if [[ "$cc_link" -ne 0 ]]; then
    cc_objects="build/$out_name.bc" \
        cc_secret_objects="$cc_secret_objects" \
        cc_build_dir="build/$out_name" \
        cc_microram_output="build/$out_name.ll" \
        LLVM_SUFFIX=-13 \
        LLVM_OPT_FLAGS=-enable-new-pm=0 \
        COMPILER_RT_HOME=$support_dir/../llvm-project/compiler-rt/build-13 \
        bash -x $PICOLIBC_HOME/lib/fromager-link.sh microram
    llc-13 "build/$out_name.ll" -o "build/$out_name.s" -relocation-model=static -mattr=+m
fi
