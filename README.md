This repo includes all the Cheesecloth tools and examples as submodules, along
with scripts for building everything.

# Usage

* Run `git submodule update --init` to initialize all submodules
* Run `scripts/run_grit` to build all dependencies and generate ZKIF for the
  `grit` example.  (Note that the ZKIF output files are about 20GB.)

See `scripts/common.sh` for details of the build steps for each component.
