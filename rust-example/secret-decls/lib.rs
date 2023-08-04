#![no_std]

// This file should declare any constant, type aliases, etc, that are used for specifying the types
// of the secret inputs.
pub const MAX_INPUT_LEN: usize = 8;

// Declarations of secret inputs.  The actual input data will be provided in `secrets/lib.rs`.
extern "C" {
    static INPUT_LEN: usize;
    static INPUT_DATA: [i32; MAX_INPUT_LEN];
}

// This function can contain other relevant definitions, such as this helper function for accessing
// the secret input.
pub fn secret_input() -> &'static [i32] {
    unsafe {
        &INPUT_DATA[..INPUT_LEN]
    }
}
