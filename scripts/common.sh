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
