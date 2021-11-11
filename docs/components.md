# Cheesecloth components

Given an input program, the Cheesecloth pipeline performs the following steps:

1. Compile the input program to LLVM.  The program consists of C/C++ code plus
   some secret input.  The output is a `.ll` file (LLVM IR, in textual format).
2. Compile the LLVM code to MicroRAM and run it to produce a record of a buggy
   execution.  The output is a `.cbor` file.
3. Generate an arithmetic circuit that checks that the execution is both valid
   and buggy, without revealing the details of the execution or the secret
   input.  The output is an R1CS constraint system or a SIEVE IR circuit, both
   in zkinterface format.

## 1. LLVM

We compile the input program to LLVM IR using Clang.  In addition to Clang,
this involves the following Cheesecloth components:

* `picolibc`: An implementation of the C standard library for embedded systems,
  which we have ported to run on the MicroRAM architecture.  This allows the
  input program to use all the standard C functions, such as `malloc` or
  `strcmp`.  Operations that interact with the operating system (system calls)
  require special handling, since there is no operating system available when
  running in zero knowledge on the virtual MicroRAM CPU.  We often need to add
  support for additional system calls as part of getting a new input program
  working.

* `compiler-rt`: A library of low-level support routines that are sometimes
  used by Clang.  We mainly use this to provide software floating point
  support: `compiler-rt` implements floating-point arithmetic, which the
  MicroRAM architecture does not support, in terms of ordinary integer
  arithmetic.

* `llvm-passes`: Custom transformation passes for rewriting LLVM code.  We use
  these in cases where we need to rewrite the LLVM code partway through the
  optimization process.

## 2. MicroRAM

`MicroRAM` is responsible for the following:

* Compile LLVM to MicroRAM assembly code.
* Run the MicroRAM code through an interpreter, which is instrumented to
  produce a complete execution trace including advice values.  The interpreter
  is also instrumented to detect certain kinds of bugs, such as memory errors;
  this information is used to generate the correct advice values in some cases,
  and in general, it's convenient to alert the user early so they don't waste
  time running a non-buggy execution through the rest of the toolchain.
* Generate a segment graph, which affects the structure of the final circuit.
  This is part of the public PC optimization.

The output includes the MicroRAM code, the execution trace, the advice values,
and the segment graph.  These are stored in CBOR format using a custom schema,
so we commonly refer to `MicroRAM` outputs as "CBOR files".

## 3. witness-checker

`witness-checker` is responsible for the following:

* Build an arithmetic circuit, whose output evaluates to `true` if the secret
  execution trace is valid and exhibits some kind of bug.
* Optimize the circuit.  This notably includes constant folding and memory
  folding (which is similar to store-to-load forwarding in CPUs), which provide
  a significant reduction in circuit size as part of the public PC
  optimization.
* Convert the circuit to R1CS or SIEVE IR format for consumpiton by TA2
  zero-knowledge proof systems.  The R1CS backend is older, and is more-or-less
  obsolete now that the SIEVE IR format has been standardized.

The name `witness-checker` is slightly misleading: its purpose is not to check
the validity of the witness, but to generate a circuit that checks the witness.


## Example programs

* `grit`: A tool for converting images to the native format of the Game Boy
  Advance, used for hobbyist game development.  In the version we use for this
  example, a malformed `.bmp` header with an invalid palette size causes a
  buffer overflow.  This example runs for about 6,000 steps in the MicroRAM
  interpreter.

* `ffmpeg`: A library of codecs for various audio, video, and image formats.
  In our version, when running the `.gif` decoder, certain frame modes and
  dimensions will trigger a buffer overflow.  This example runs for about
  76,000 steps.

* `openssl`: An implementation of SSL/TLS for encrypting internet traffic.  We
  use an old version that contains the famous Heartbleed vulnerability.  This
  example runs for about 1,300,000 steps.

