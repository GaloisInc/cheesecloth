#!/bin/bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <command> <dir>" 1>&2
    exit 1
fi

cmd=$1
input_dir=$2/sieve
output_dir=$2/dmc
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

swanky_dir=$HOME/swanky
dmc_dir=$swanky_dir/diet-mac-and-cheese
(cd $dmc_dir && cargo build --release --features ff)

edo() {
    echo " >>> $*"
    "$@"
}

export PYTHONUNBUFFERED="true"

edo mkdir -p $output_dir
if [ "$cmd" == "prover" ]; then
    edo /usr/bin/time $swanky_dir/target/release/dietmc_0p --relation $input_dir/002_relation.sieve --instance /dev/null prover --witness $input_dir/001_private_inputs_0.sieve |& tee $output_dir/prover.log
elif [ "$cmd" == "prover-count" ]; then
    edo /usr/bin/time $swanky_dir/target/release/dietmc_0p --relation $input_dir/002_relation.sieve --instance /dev/null prover --witness $input_dir/001_private_inputs_0.sieve |& tee $output_dir/prover-count.log &
    edo sleep 3
    # edo $script_dir/proxy.py -p 5527 -q 5528 # |& tee $output_dir/proxy-count.log
    edo $script_dir/proxy.py -p 5527 -q 5528 > $output_dir/proxy-count.log

elif [ "$cmd" == "verifier" ]; then
    edo /usr/bin/time $swanky_dir/target/release/dietmc_0p  --connection-addr 127.0.0.1:5528 --relation $input_dir/002_relation.sieve --instance /dev/null |& tee $output_dir/verifier.log
else
    echo "Unknown command" 1>&2
    exit 1
fi
