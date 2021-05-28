cc_dir="$(dirname "$0")"/..

export LLVM_SUFFIX=-9


build_llvm_passes() {
    make -C "$cc_dir/llvm-passes" passes.so
}

clean_llvm_passes() {
    rm -fv "$cc_dir/llvm-passes/passes.so"
}


build_picolibc() {
    mkdir -p "$cc_dir/picolibc/build"
    (
        cd "$cc_dir/picolibc/build"
        if ! [ -f build.ninja ]; then
            ../scripts/do-fromager-configure
        fi
        ninja install
    )
}

clean_picolibc() {
    rm -rf "$cc_dir/picolibc/build"
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
        cargo build --release --features bellman
    )
}

clean_witness_checker() {
    rm -r "$cc_dir/witness-checker/target"
}


# Examples

build_grit() {
    build_llvm_passes
    build_picolibc
    (
        cd "$cc_dir/grit"
        fromager/build.sh microram
    )
}

clean_grit() {
    rm -rf \
        "$cc_dir/grit/build" \
        "$cc_dir/grit/driver-link.ll" \
        "$cc_dir/grit/"lib*.a
}

run_grit() {
    build_grit
    build_microram
    build_witness_checker
    mkdir -p "$cc_dir/out/grit"
    (
        cd "$cc_dir/MicroRAM"
        stack run compile -- \
            --from-llvm ../grit/driver-link.ll \
            6000 \
            -o ../out/grit/grit.cbor \
            --verbose \
            2>&1 | tee ../out/grit/microram.log
    )
    (
        cd "$cc_dir/out/grit"
        ../../witness-checker/target/release/cheesecloth \
            grit.cbor --stats --zkif-out zkif \
            2>&1 | tee witness-checker.log
    )
}


build_ffmpeg() {
    build_llvm_passes
    build_picolibc
    (
        cd "$cc_dir/ffmpeg"
        [ -f Makefile ] || CVE-2013-0864/configure.sh
        DRIVER_CFLAGS='-DSILENT' CVE-2013-0864/build.sh microram
    )
}

clean_grit() {
    make -C $cc_dir/ffmpeg clean

    rm -rf \
        "$cc_dir/ffmpeg/build" \
        "$cc_dir/ffmpeg/driver-link.ll"
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
            80000 \
            --priv-segs 6800 \
            -o ../out/ffmpeg/ffmpeg.cbor \
            --verbose \
            2>&1 | tee ../out/ffmpeg/microram.log
    )
    (
        cd "$cc_dir/out/ffmpeg"
        # Build the circuit but don't enable ZKIF output, since it's very
        # expensive.
        ../../witness-checker/target/release/cheesecloth \
            ffmpeg.cbor --stats \
            2>&1 | tee witness-checker.log
    )
}
