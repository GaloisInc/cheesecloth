# Cheesecloth

Cheesecloth is a compilation pipeline for producing Zero-Knowledge (ZK) Proofs about LLVM (C, C++, Rust) programs.
Cheesecloth enables analysts to prove that they know a vulnerability in a program, without revealing the details of the vulnerability or the inputs that exploit it.
In addition, it can verify the execution of arbritrary LLVM programs in ZK.
This toolchain accompanies the paper "Cheesecloth: Zero-Knowledge Proofs of Real-World Vulnerabilities" (Usenix 2023).

This repo includes all the Cheesecloth tools and examples as submodules, along
with scripts for building everything.

# Usage

* Run `git submodule update --init --recursive` to initialize all submodules

* Run `scripts/run_grit` to build all dependencies and generate ZKIF for the
  `grit` example.  (Note that the ZKIF output files are about 20GB.)  A
  successful run should produce output like the following:

  ```
  internal evaluator: 222507 asserts passed, 0 failed; found 1 bugs; overall status: GOOD
  validating zkif...
  The statement is COMPLIANT with the specification!
  The statement is TRUE!
  ```

* Run `scripts/run_ffmpeg` to build the FFmpeg example and generate a circuit.
  Note that this script requires 32 GB of RAM at minimum.
  This script does not generate ZKIF, since the constraint system for this example
  would be almost 200 GB in size.  A successful run should produce output like
  the following:

  ```
  internal evaluator: 2873819 asserts passed, 0 failed; found 1 bugs; overall status: GOOD
  ```

See `scripts/common.sh` for details of the build steps for each component.

# License

[MIT License](/LICENSE)

# Contributors

- Santiago Cuéllar
- James Parker
- Stuart Pernsteiner

# Acknowledgments

This material is based upon work supported by the Defense Advanced Research Projects Agency (DARPA) under Contract No. HR001120C0085. Any opinions, findings, conclusions, or recommendations expressed in this material are those of the author(s) and do not necessarily reflect the views of the Defense Advanced Research Projects Agency (DARPA).

Copyright © 2023 Galois, Inc.
