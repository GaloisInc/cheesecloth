A simple Rust example for running under MicroRAM.

Secret inputs are declared in `secret-decls/lib.rs`.  The actual secret data is
in `secrets/lib.rs`.

## Building

To build and run natively:

```sh
cargo run --bin rust_example --features inline-secrets
```

To build for MicroRAM:

```sh
# TODO: This doesn't work yet - some llvm-passes and picolibc changes must be
# merged first
../rust-support/build_microram.sh secrets secrets
../rust-support/build_microram.sh rust_example
# Produces build/rust_example.s
```

