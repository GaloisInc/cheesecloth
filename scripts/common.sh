cc_dir=$(cd `dirname "$0"`/.. && pwd)

export LLVM_SUFFIX=-11

# Exported paths to picolibc build directories for use in e.g.
# Makefiles.
export PICOLIBC_DEFAULT_BUILD="$cc_dir/picolibc/build"
export PICOLIBC_NOPOISON_BUILD="$cc_dir/picolibc/build-nopoison"

build_llvm_passes() {
    make -C "$cc_dir/llvm-passes" passes.so
}

clean_llvm_passes() {
    rm -fv "$cc_dir/llvm-passes/passes.so" "$cc_dir/llvm-passes/"*.o
}

# Build picolibc with the default build settings.
#
# When using this, use $PICOLIBC_DEFAULT_BUILD as your picolibc
# directory.
build_picolibc() {
    mkdir -p "$PICOLIBC_DEFAULT_BUILD"
    (
        cd "$PICOLIBC_DEFAULT_BUILD"
        if ! [ -f build.ninja ]; then
            ../scripts/do-fromager-configure
        fi
        ninja install
    )
}

# Build picolibc with malloc poisoning disabled for input programs that
# don't need or want it.
#
# When using this, use $PICOLIBC_NOPOISON_BUILD as your picolibc
# directory.
build_picolibc_nopoison() {
    mkdir -p "$PICOLIBC_NOPOISON_BUILD"
    (
        cd "$PICOLIBC_NOPOISON_BUILD"
        if ! [ -f build.ninja ]; then
            ../scripts/do-fromager-configure -Ddisable-malloc-poison=true
        fi
        ninja install
    )
}

clean_picolibc() {
    rm -rf "$PICOLIBC_DEFAULT_BUILD" "$PICOLIBC_NOPOISON_BUILD"
}


build_compiler_rt() {
    mkdir -p "$cc_dir/llvm-project/compiler-rt/build"
    (
        cd "$cc_dir/llvm-project/compiler-rt/build"
        if ! [ -f build.ninja ]; then
            # Setting CFLAGS=-flto is not enough, because compiler-rt tries to
            # force disable LTO via -fno-lto.  We prevent this by adding
            # -DCOMPILER_RT_HAS_FNO_LTO_FLAG=OFF.
            #
            # CMake tries to check whether the C compiler "works", which fails
            # in this cross-compiling configuration.  As a hack, we bypass this
            # check by setting CMAKE_C_COMPILER_WORKS.  There's probably some
            # better way of doing this, but this approach is partially
            # consistent with the compiler-rt docs:
            # https://llvm.org/docs/HowToCrossCompileBuiltinsOnArm.html
            cmake .. -G Ninja \
                -DCMAKE_BUILD_TYPE=Release \
                -DCMAKE_ASM_COMPILER_TARGET=riscv64-unknown-elf \
                -DCMAKE_ASM_FLAGS='-march=rv64im -flto' \
                -DCMAKE_C_COMPILER=clang${LLVM_SUFFIX} \
                -DCMAKE_C_COMPILER_TARGET=riscv64-unknown-elf \
                -DCMAKE_C_FLAGS='-march=rv64im -flto -gcc-toolchain /var/empty' \
                -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld \
                -DCMAKE_C_COMPILER_WORKS=ON \
                -DLLVM_CONFIG_PATH=llvm-config${LLVM_SUFFIX} \
                -DCOMPILER_RT_STANDALONE_BUILD=ON \
                -DCOMPILER_RT_BAREMETAL_BUILD=ON \
                -DCOMPILER_RT_BUILD_CRT=OFF \
                -DCOMPILER_RT_BUILD_SANITIZERS=OFF \
                -DCOMPILER_RT_BUILD_XRAY=OFF \
                -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
                -DCOMPILER_RT_BUILD_PROFILE=OFF \
                -DCOMPILER_RT_BUILD_MEMPROF=OFF \
                -DCOMPILER_RT_BUILD_ORC=OFF \
                -DCOMPILER_RT_BUILD_GWP_ASAN=OFF \
                -DCOMPILER_RT_HAS_FNO_LTO_FLAG=OFF \
                -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON
        fi
        ninja
        cp -v lib/*/libclang_rt.builtins-riscv64.a .
    )
}

clean_compiler_rt() {
    rm -rf "$cc_dir/llvm-project/compiler-rt/build"
}


build_microram() {
    (
        cd "$cc_dir/MicroRAM"
        stack build
    )
}

clean_microram() {
    (
        cd "$cc_dir/MicroRAM"
        stack clean
    )
}


build_witness_checker() {
    (
        cd "$cc_dir/witness-checker"
        cargo build --release --features bellman,sieve_ir
    )
}

clean_witness_checker() {
    rm -rf "$cc_dir/witness-checker/target"
}


# Examples

build_grit() {
    build_llvm_passes
    build_picolibc
    build_compiler_rt
    (
        cd "$cc_dir/grit"
        fromager/build.sh microram
        llc${LLVM_SUFFIX} driver-link.ll
    )
}

clean_grit() {
    rm -rf \
        "$cc_dir/grit/build" \
        "$cc_dir/grit/driver-link.ll" \
        "$cc_dir/grit/driver-link.s" \
        "$cc_dir/grit/"lib*.a
}

run_grit() {
    build_grit
    build_microram
    build_witness_checker
    mkdir -p "$cc_dir/out/grit"
    (
        cd "$cc_dir/MicroRAM"
        time stack run compile -- \
            --riscv ../grit/driver-link.s \
            6000 \
            -o ../out/grit/grit.cbor \
            --verbose \
            2>&1 | tee ../out/grit/microram.log
    )
    (
        out_dir="$cc_dir/out/grit"
        cd "$cc_dir"
        time witness-checker/target/release/cheesecloth \
            $out_dir/grit.cbor --stats --sieve-ir-out $out_dir/sieve \
            2>&1 | tee $out_dir/witness-checker.log
    )
}


build_ffmpeg() {
    build_llvm_passes
    build_picolibc
    build_compiler_rt
    (
        cd "$cc_dir/ffmpeg"
        [ -f config.h ] || CVE-2013-0864/configure.sh
        DRIVER_CFLAGS='-DSILENT' CVE-2013-0864/build.sh microram
    )
}

clean_ffmpeg() {
    make -C $cc_dir/ffmpeg clean

    rm -rf \
        "$cc_dir/ffmpeg/build" \
        "$cc_dir/ffmpeg/driver-link.ll" \
        "$cc_dir/ffmpeg/driver" \
        "$cc_dir/ffmpeg/config.h"
}

run_ffmpeg() {
    build_ffmpeg
    build_microram
    build_witness_checker
    mkdir -p "$cc_dir/out/ffmpeg"
    (
        cd "$cc_dir/MicroRAM"
        stack run compile -- \
            --from-llvm ../ffmpeg/driver-link.ll \
            79000 \
            --priv-segs 6700 \
            -o ../out/ffmpeg/ffmpeg.cbor \
            --verbose \
            2>&1 | tee ../out/ffmpeg/microram.log
    )
    (
        out_dir="$cc_dir/out/ffmpeg"
        cd "$cc_dir"
        time witness-checker/target/release/cheesecloth \
            $out_dir/ffmpeg.cbor --stats --sieve-ir-out $out_dir/sieve \
            2>&1 | tee $out_dir/witness-checker.log
    )
}

build_matrixmul_simple() {
    build_llvm_passes
    build_picolibc_nopoison
    build_compiler_rt
    (
        cd "$cc_dir/matrixmul-simple"
        [ -f driver-link.ll ] || cc_instrument=1 make
    )
}

build_openssl() {
    build_llvm_passes
    build_picolibc
    build_compiler_rt
    (
        cd "$cc_dir/openssl"
        if ! [ -f libssl.a ]; then
            ./fromager-config.sh
            make depend
            make -C crypto
            make -C ssl
        fi
    )
    (
        cd "$cc_dir/openssl-driver"
        [ -f driver-link.ll ] || cc_instrument=1 cc_flatten_init=1 make all
    )
}

clean_openssl() {
    echo clean_openssl not yet implemented
    exit 1
}

run_matrixmul_simple() {
    build_matrixmul_simple
    build_microram
    build_witness_checker
    out_dir="$cc_dir/out/matrixmul-simple"
    mkdir -p $out_dir
    (
        cd "$cc_dir/MicroRAM"
        stack run compile -- \
            --from-llvm ../matrixmul-simple/driver-link.ll \
            6100 \
            -o ../out/matrixmul-simple/matrixmul-simple.cbor \
            --verbose \
            2>&1 | tee ../out/matrixmul-simple/microram.log
    )
    (
        cd "$cc_dir"
        /usr/bin/time witness-checker/target/release/cheesecloth \
            $out_dir/matrixmul-simple.cbor --stats --sieve-ir-out $out_dir/sieve \
            --skip-backend-validation \
            2>&1 | tee $out_dir/witness-checker.log
    )
}

run_openssl() {
    build_openssl
    build_microram
    build_witness_checker
    mkdir -p "$cc_dir/out/openssl"
    (
        cd "$cc_dir/MicroRAM"
        stack run compile -- \
            --from-llvm ../openssl-driver/driver-link.ll \
            1300000 --regs 11 --priv-segs 110000 \
            --mode leak-tainted \
            -o ../out/openssl/openssl.cbor \
            --verbose \
            2>&1 | tee ../out/openssl/microram.log
    )
    (
        out_dir="$cc_dir/out/openssl"
        cd "$cc_dir"
        /usr/bin/time witness-checker/target/release/cheesecloth \
            $out_dir/openssl.cbor --stats --sieve-ir-out $out_dir/sieve \
            --skip-backend-validation \
            2>&1 | tee $out_dir/witness-checker.log
    )
}
