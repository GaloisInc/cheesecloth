#!/bin/bash
set -xeuo pipefail

support_dir="$(dirname "$0")"

name="$1"

if [[ "$#" -eq 2 ]]; then
    package_dir=$2
else
    package_dir=.
fi

features="${features-},microram"

mkdir -p build

# Remove existing bitcode, so that only the most recent bitcode is present
# after cargo finishes the build.
find target -name "$name-*.bc" -delete

# Build RISC-V ASM for the victim (server) program:
RUSTC_BOOTSTRAP=1 cargo +1.56.0 rustc \
    --release -Z build-std=core,alloc --target $support_dir/target-rv64.json \
    --manifest-path "$package_dir/Cargo.toml" --bin "$name" \
    --features "$features" -- --emit llvm-bc -Z no-link
# The output filename contains a random hash.  Find it as follows:
bc_path="$(find target -name "$name-*.bc")"
cp "$bc_path" "build/$name.bc"

if [ -z "$PICOLIBC_HOME" ]; then
    PICOLIBC_HOME="$support_dir/../picolibc/build/image/picolibc/riscv64-unknown-fromager"
fi

case $name in
    secrets)
        # Don't link
        ;;
    *)
        # Link normally, including secrets
        cc_objects="build/$name.bc" \
            cc_secret_objects="build/secrets.bc" \
            cc_build_dir="build/$name" \
            cc_microram_output="build/$name.ll" \
            LLVM_SUFFIX=-13 \
            LLVM_OPT_FLAGS=-enable-new-pm=0 \
            COMPILER_RT_HOME=$support_dir/../llvm-project/compiler-rt/build-13 \
            bash -x $PICOLIBC_HOME/lib/fromager-link.sh microram
        llc-13 "build/$name.ll" -o "build/$name.s" -relocation-model=static -mattr=+m
        ;;
esac
