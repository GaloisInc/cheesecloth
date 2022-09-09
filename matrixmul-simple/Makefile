
# Settings and rules for the native build of the example, so we have
# easy access to a version that can do console output.
NATIVE := ./native
NATIVE_BIN := native/matrixmul
NATIVE_INCLUDE := ./src/
NATIVE_CC := gcc -I$(NATIVE_INCLUDE)

# Settings for the cheesecloth build.
OUT := ./out
SOURCES := $(shell find ./src/ -name '*.c')
PICOLIBC_HOME := $(PICOLIBC_NOPOISON_BUILD)/image/picolibc/x86_64-unknown-fromager
CLANG_DIR=$(shell clang${LLVM_SUFFIX} -print-resource-dir)
CFLAGS=-flto -mprefer-vector-width=1 \
    -nostdinc                         \
    -isystem $(CLANG_DIR)/include     \
    -isystem $(PICOLIBC_HOME)/include \
    -ggdb                             \
    -Os
CC := clang${LLVM_SUFFIX} ${CFLAGS}
OBJECTS := \
	$(OUT)/main.o \
	$(OUT)/secret_inputs.o \
	$(OUT)/matrix_mul.o

# Top-level rules
all: native cheesecloth

clean: native-clean cheesecloth-clean

# Rules for the native build.
native: native-common $(NATIVE_BIN)

native-common:
	$(shell mkdir -p $(NATIVE))

native-clean:
	rm -rf $(NATIVE)

native/matrix_mul.o:
	$(NATIVE_CC) -c -Wall src/matrix_mul.c -o $@

native/secret_inputs.o:
	$(NATIVE_CC) -c -Wall src/secret_inputs.c -o $@

$(NATIVE_BIN): src/main.c native/matrix_mul.o native/secret_inputs.o
	$(NATIVE_CC) -Wall $? -o $(NATIVE_BIN)

# Rules for the cheesecloth build.
$(OUT)/main.o:
	$(CC) -I./src/ -c src/main.c -o $@

$(OUT)/secret_inputs.o:
	$(CC) -I./src/ -c src/secret_inputs.c -o $@

$(OUT)/matrix_mul.o:
	$(CC) -I./src/ -c src/matrix_mul.c -o $@

cheesecloth: cheesecloth-common $(OBJECTS) picolib

cheesecloth-common:
	$(shell mkdir -p $(OUT))

cheesecloth-clean:
	rm -rf $(OUT)
	rm -f ./driver-link.ll ./driver

picolib: $(SOURCES)
	cc_secret_objects=$(OUT)/secret_inputs.o \
	cc_objects="$(OUT)/main.o $(OUT)/matrix_mul.o" \
	COMPILER_RT_HOME=${PWD}/../llvm-project/compiler-rt/build \
	  $(PICOLIBC_HOME)/lib/fromager-link.sh
