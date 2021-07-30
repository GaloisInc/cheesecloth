This repo includes all the Cheesecloth tools and examples as submodules, along
with scripts for building everything.

# Usage

* Run `git submodule update --init` to initialize all submodules

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
