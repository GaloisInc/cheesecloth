cc_dir=$(cd `dirname "$0"`/.. && pwd)

export LLVM_SUFFIX=-11

# Exported paths to picolibc build directories for use in e.g.
# Makefiles.
export PICOLIBC_DEFAULT_BUILD="$cc_dir/picolibc/build"
export PICOLIBC_NOPOISON_BUILD="$cc_dir/picolibc/build-nopoison"
export PICOLIBC_LLVM_13_BUILD="$cc_dir/picolibc/build-llvm-13"


build_llvm_passes_common() {
    local suffix
    [ -n "$llvm_version" ] && suffix="-$llvm_version"
    LLVM_SUFFIX="${suffix}" BUILD_DIR="build${suffix}" \
        make -C "$cc_dir/llvm-passes" "build${suffix}/passes.so"
}

build_llvm_passes() {
    : ${llvm_version:=11}
    build_llvm_passes_common
}

build_llvm_passes_13() {
    llvm_version=13 build_llvm_passes_common
}

clean_llvm_passes() {
    rm -fv "$cc_dir"/llvm-passes/build*/passes.so "$cc_dir"/llvm-passes/build*/*.o
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


# Build picolibc with LLVM 13 using the default build settings.
#
# When using this, use $PICOLIBC_LLVM_13_BUILD as your picolibc
# directory.
build_picolibc_13() {
    mkdir -p "$PICOLIBC_LLVM_13_BUILD"
    (
        cd "$PICOLIBC_LLVM_13_BUILD"
        if ! [ -f build.ninja ]; then
            LLVM_SUFFIX=-13 ../scripts/do-fromager-configure
        fi
        LLVM_SUFFIX=-13 ninja install
    )
}

clean_picolibc() {
    rm -rf \
        "$PICOLIBC_DEFAULT_BUILD" \
        "$PICOLIBC_NOPOISON_BUILD" \
        "$PICOLIBC_LLVM_13_BUILD"
}


build_compiler_rt_common() {
    local suffix
    [ -n "$llvm_version" ] && suffix="-$llvm_version"
    mkdir -p "$cc_dir/llvm-project/compiler-rt/build${suffix}"
    (
        cd "$cc_dir/llvm-project/compiler-rt/build${suffix}"
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
                -DCMAKE_C_COMPILER=clang${suffix} \
                -DCMAKE_C_COMPILER_TARGET=riscv64-unknown-elf \
                -DCMAKE_C_FLAGS='-march=rv64im -flto -gcc-toolchain /var/empty' \
                -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld \
                -DCMAKE_C_COMPILER_WORKS=ON \
                -DLLVM_CONFIG_PATH=llvm-config${suffix} \
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

build_compiler_rt() {
    : ${llvm_version:=11}
    build_compiler_rt_common
}

build_compiler_rt_13() {
    llvm_version=13 build_compiler_rt_common
}

clean_compiler_rt() {
    rm -rf "$cc_dir/llvm-project/compiler-rt/build"*
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
            3800 \
            -o ../out/grit/grit.cbor \
            --verbose \
            2>&1 | tee ../out/grit/microram.log
    )
    (
        out_dir="$cc_dir/out/grit"
        cd "$cc_dir"
        time witness-checker/target/release/cheesecloth \
            $out_dir/grit.cbor \
            --boolean-sieve-ir-v2-out $out_dir/sieve \
            --skip-backend-validation \
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
        DRIVER_CFLAGS='-DSILENT' cc_flatten_init=1 CVE-2013-0864/build.sh microram
        llc${LLVM_SUFFIX} driver-link.ll
    )
}

clean_ffmpeg() {
    make -C $cc_dir/ffmpeg clean

    rm -rf \
        "$cc_dir/ffmpeg/build" \
        "$cc_dir/ffmpeg/driver-link.ll" \
        "$cc_dir/ffmpeg/driver-link.s" \
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
            --riscv ../ffmpeg/driver-link.s \
            28000 \
            --priv-segs 2700 \
            -o ../out/ffmpeg/ffmpeg.cbor \
            --verbose \
            2>&1 | tee ../out/ffmpeg/microram.log
    )
    (
        out_dir="$cc_dir/out/ffmpeg"
        cd "$cc_dir"
        time witness-checker/target/release/cheesecloth \
            $out_dir/ffmpeg.cbor \
            --boolean-sieve-ir-v2-out $out_dir/sieve \
            --skip-backend-validation \
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
            $out_dir/matrixmul-simple.cbor \
            --boolean-sieve-ir-v2-out $out_dir/sieve \
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
            $out_dir/openssl.cbor \
            --boolean-sieve-ir-v2-out $out_dir/sieve \
            --skip-backend-validation \
            2>&1 | tee $out_dir/witness-checker.log
    )
}


build_rust_example() {
    build_llvm_passes_13
    build_picolibc_13
    build_compiler_rt_13
    (
        export CHEESECLOTH_HOME="$cc_dir"
        export COMPILER_RT_HOME="$cc_dir/llvm-project/compiler-rt/build-13"
        export LLVM_PASSES_HOME="$cc_dir/llvm-passes/build-13"
        export PICOLIBC_HOME="$PICOLIBC_LLVM_13_BUILD/image/picolibc/riscv64-unknown-fromager"

        cd "$cc_dir/rust-example"
        ../rust-support/build_microram.sh secrets secrets
        ../rust-support/build_microram.sh rust_example
    )
}

run_rust_example() {
    build_rust_example
    build_microram
    build_witness_checker
    out_dir="$cc_dir/out/rust-example"
    mkdir -p $out_dir
    (
        cd "$cc_dir/MicroRAM"
        stack run compile -- \
            --riscv ../rust-example/build/rust_example.s \
            1000 \
            -o ../out/rust-example/rust-example.cbor \
            --verbose \
            2>&1 | tee ../out/rust-example/microram.log
    )
    (
        cd "$cc_dir"
        /usr/bin/time witness-checker/target/release/cheesecloth \
            $out_dir/rust-example.cbor \
            --boolean-sieve-ir-v2-out $out_dir/sieve \
            --skip-backend-validation \
            2>&1 | tee $out_dir/witness-checker.log
    )
}


# Scuttlebutt MicroRAM invocations
scuttlebutt_microram_attacker() {
    # Should be run from the MicroRAM/ directory
    out_dir="$cc_dir/out/scuttlebutt"
    echo ' >>> microram: attacker'
    stack exec compile -- \
        --domain attacker \
        --domain-input-riscv ../scuttlebutt-attack/build/attacker.s \
        --domain-secret 22000,160 \
        --domain kernel \
        --domain-input-riscv ../scuttlebutt-attack/build/kernel_attacker.s \
        --domain-privileged \
        110000 \
        --pub-seg-mode none \
        -o $out_dir/ssb-attacker.cbor \
        --verbose \
        2>&1 | tee $out_dir/microram-attacker.log
}

scuttlebutt_microram_victim() {
    # Should be run from the MicroRAM/ directory
    out_dir="$cc_dir/out/scuttlebutt"
    echo ' >>> microram: victim'
    stack exec compile -- \
        --riscv ../scuttlebutt-attack/build/victim.s \
        4400000 \
        -o $out_dir/ssb-victim.cbor \
        --verbose \
        2>&1 | tee $out_dir/microram-victim.log
}

scuttlebutt_microram_checker() {
    # Should be run from the MicroRAM/ directory
    out_dir="$cc_dir/out/scuttlebutt"
    echo ' >>> microram: checker'
    stack exec compile -- \
        --riscv ../scuttlebutt-attack/build/checker.s \
        490 \
        -o $out_dir/ssb-checker.cbor \
        --verbose \
        2>&1 | tee $out_dir/microram-checker.log
}

# Build scuttlebutt `attacker.s` and dummy `kernel_attacker.s` only.
build_scuttlebutt_attacker() {
    build_llvm_passes_13
    build_picolibc_13
    build_compiler_rt_13
    (
        export CHEESECLOTH_HOME="$cc_dir"
        export COMPILER_RT_HOME="$cc_dir/llvm-project/compiler-rt/build-13"
        export LLVM_PASSES_HOME="$cc_dir/llvm-passes/build-13"
        export PICOLIBC_HOME="$PICOLIBC_LLVM_13_BUILD/image/picolibc/riscv64-unknown-fromager"

        cd "$cc_dir/scuttlebutt-attack"
        ./build.sh attacker
        ./build.sh secrets_dummy
        ssb_use_dummy_secrets=1 ./build.sh kernel_attacker
    )
}

# Run MicroRAM to produce `ssb-attacker.cbor`.
build_scuttlebutt_attacker_cbor() {
    build_scuttlebutt_attacker
    build_microram
    build_witness_checker
    out_dir="$cc_dir/out/scuttlebutt"
    mkdir -p $out_dir
    (
        cd "$cc_dir/MicroRAM"
        scuttlebutt_microram_attacker
    )
}

# Regenerate scuttlebutt parameters after building a fresh `attacker.s`.
regenerate_scuttlebutt() {
    build_scuttlebutt_attacker_cbor

    build_witness_checker
    (
        cd "$cc_dir/scuttlebutt-attack"
        # Update commitment randomness and seed, and create `commitment.env`.
        COMMITMENT_TOOL=$cc_dir/witness-checker/target/release/commitment_tool \
            python3 update_commitment.py $cc_dir/out/scuttlebutt/ssb-attacker.cbor
        # Record communication trace and update secrets.
        ./record.sh
    )
}

# Build all scuttlebutt asm files.
build_scuttlebutt() {
    build_llvm_passes_13
    build_picolibc_13
    build_compiler_rt_13

    if ! [ -f "$cc_dir/scuttlebutt-attack/commitment.env" ]; then
        regenerate_scuttlebutt
    fi

    (
        export CHEESECLOTH_HOME="$cc_dir"
        export COMPILER_RT_HOME="$cc_dir/llvm-project/compiler-rt/build-13"
        export LLVM_PASSES_HOME="$cc_dir/llvm-passes/build-13"
        export PICOLIBC_HOME="$PICOLIBC_LLVM_13_BUILD/image/picolibc/riscv64-unknown-fromager"

        cd "$cc_dir/scuttlebutt-attack"
        ./build.sh secrets
        ./build.sh kernel_attacker
        ./build.sh victim
        ./build.sh checker
        # We specifically avoid building `attacker.s` here.  We build it once
        # as part of `regenerate_scuttlebutt`, commit to it, and never rebuild
        # it again.  This helps us avoid potential issues with nondeterministic
        # builds.
    )
}

clean_scuttlebutt() {
    rm -rf \
        "$cc_dir"/scuttlebutt-attack/build \
        "$cc_dir"/scuttlebutt-attack/commitment.env \
        "$cc_dir"/scuttlebutt-attack/constants/lib.rs \
        "$cc_dir"/scuttlebutt-attack/secrets/lib.rs
}

run_scuttlebutt() {
    build_scuttlebutt
    build_microram
    build_witness_checker
    out_dir="$cc_dir/out/scuttlebutt"
    mkdir -p $out_dir
    (
        cd "$cc_dir/MicroRAM"
        scuttlebutt_microram_checker
        scuttlebutt_microram_attacker
        scuttlebutt_microram_victim
    )

    (
        cd "$cc_dir"

        equivs=''
        set_uncommitted=''
        mem_prefix='.rodata.secret.ssb_'
        for name in events num_valid_events channels threads data; do
            set_uncommitted="
                $set_uncommitted
                --set-uncommitted $mem_prefix$name
            "
            equivs="
                $equivs
                --equiv checker.$mem_prefix$name==attacker.$mem_prefix$name
                --equiv checker.$mem_prefix$name==victim.$mem_prefix$name
            "
        done

        echo ' >>> add commitment'
        . scuttlebutt-attack/commitment.env
        witness-checker/target/release/commitment_tool \
            update-cbor \
            --set-commitment "$ssb_commitment" \
            --set-randomness "$ssb_randomness" \
            --randomness-symbol CC_COMMITMENT_RANDOMNESS \
            --randomness-length 32 \
            $set_uncommitted \
            --set-privilege-levels \
            -o "$out_dir"/ssb-attacker-committed.cbor \
            "$out_dir"/ssb-attacker.cbor \
            2>&1 | tee $out_dir/commitment.log

        echo ' >>> combine executions'
        time python3 witness-checker/scripts/multi_exec.py \
            --exec checker="$out_dir"/ssb-checker.cbor \
            --exec attacker="$out_dir"/ssb-attacker-committed.cbor \
            --exec victim="$out_dir"/ssb-victim.cbor \
            $equivs \
            --verbose \
            --out "$out_dir"/ssb.cbor \
            2>&1 | tee $out_dir/multi_exec.log
    )

    (
        cd "$cc_dir"
        echo ' >>> witness-checker'
        /usr/bin/time witness-checker/target/release/cheesecloth \
            $out_dir/ssb.cbor \
            --validate-only \
            --expect-write 0xfffffffffffffff0 \
            --boolean-sieve-ir-v2-out $out_dir/sieve \
            --skip-backend-validation \
            2>&1 | tee $out_dir/witness-checker.log
    )
}
