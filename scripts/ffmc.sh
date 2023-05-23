#!/bin/bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "usage: $0 <command> <input_dir> <output_dir>" 1>&2
    exit 1
fi

cmd=$1
input_dir=$2
output_dir=$3
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

swanky_dir=$HOME/swanky
(cd $swanky_dir && cargo build --release --features exe)

edo() {
    echo " >>> $*"
    "$@"
}

if [ "$cmd" == "plaintext" ]; then
    # time cargo run --release --bin mac-n-cheese-compiler -- compile-sieve  --relation $input_dir/002_relation.sieve --out /dev/null plaintext-evaluate $input_dir/001_private_inputs_0.sieve
    edo /usr/bin/time $swanky_dir/target/release/mac-n-cheese-compiler compile-sieve  --relation $input_dir/002_relation.sieve --out /dev/null plaintext-evaluate $input_dir/001_private_inputs_0.sieve
elif [ "$cmd" == "compile" ]; then
    edo mkdir -p $output_dir
    edo /usr/bin/time $swanky_dir/target/release/mac-n-cheese-compiler compile-sieve  --relation $input_dir/002_relation.sieve --out $output_dir/circuit.ffmc compile-prover $input_dir/001_private_inputs_0.sieve
elif [ "$cmd" == "prover" ]; then
    edo mkdir -p $output_dir
    edo /usr/bin/time $swanky_dir/target/release/mac-n-cheese-runner --event-log $output_dir/prover.mclog --address 127.0.0.1:8080  --circuit $input_dir/circuit.ffmc -r $swanky_dir/mac-n-cheese/runner/test-certs/rootCA.crt -k $swanky_dir/mac-n-cheese/runner/test-certs/galois.macncheese.example.com.pem prove $input_dir/circuit.priv
elif [ "$cmd" == "prover-count" ]; then
    edo mkdir -p $output_dir
    edo /usr/bin/time $swanky_dir/target/release/mac-n-cheese-runner --event-log $output_dir/prover.mclog --address 127.0.0.1:8081  --circuit $input_dir/circuit.ffmc -r $swanky_dir/mac-n-cheese/runner/test-certs/rootCA.crt -k $swanky_dir/mac-n-cheese/runner/test-certs/galois.macncheese.example.com.pem prove $input_dir/circuit.priv &
    edo sleep 3
    edo $script_dir/proxy.py

elif [ "$cmd" == "verifier" ]; then
    edo mkdir -p $output_dir
    edo /usr/bin/time $swanky_dir/target/release/mac-n-cheese-runner --event-log $output_dir/verifier.mclog --address 127.0.0.1:8080  --circuit $input_dir/circuit.ffmc -r $swanky_dir/mac-n-cheese/runner/test-certs/rootCA.crt -k $swanky_dir/mac-n-cheese/runner/test-certs/galois.macncheese.example.com.pem verify
else
    echo "Unknown command" 1>&2
    exit 1
fi
