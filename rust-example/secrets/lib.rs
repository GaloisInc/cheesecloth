#![no_std]
// Import necessary constants, type aliases, etc, from `secret-decls/lib.rs`.
use cheesecloth_rust_example_secret_decls::MAX_INPUT_LEN;

// We now define the actual secret input data.  There must be one `pub static` for each secret
// input declared in `secret-decls/lib.rs`.  Each static much be annotated with `no_mangle` so that
// it will satisfy the matching `extern` declaration in `secret-decls` and with `link_section` so
// that it will be placed in the secret inputs section in the resulting asm file.

#[no_mangle]
#[link_section = ".rodata.secret"]
pub static INPUT_LEN: usize = 5;

#[no_mangle]
#[link_section = ".rodata.secret"]
pub static INPUT_DATA: [i32; MAX_INPUT_LEN] = [9, 10, 3, 14, 7, 0, 0, 0];

// Note that it is incorrect to use slice or string literals here, as the data for those literals
// will be placed in the non-secret `.rodata` section by default.  For example, the following is
// incorrect:
//
// ```Rust
// #[no_mangle]
// #[link_section = ".rodata.secret"]
// pub static NOT_SO_SECRET: (&str, &[u32]) = ("foo", &[1, 2, 3]);
// ```
//
// This will produce a static named `NOT_SO_SECRET` in the `.rodata.secret` section, but the data
// `"foo"` and `1, 2, 3` that it refers to will be stored in anonymous statics in the ordinary
// `.rodata` section.  You should instead do something like the following:
//
// ```Rust
// #[no_mangle]
// #[link_section = ".rodata.secret"]
// pub static SECRET_STRING: [u8; 3] = *b"foo";
//
// #[no_mangle]
// #[link_section = ".rodata.secret"]
// pub static SECRET_INTS: [u32; 3] = [1, 2, 3];
//
// #[no_mangle]
// #[link_section = ".rodata.secret"]
// pub static ACTUALLY_SECRET: (&[u8], &[u32]) = (&SECRET_STRING, &SECRET_INTS);
// ```
//
// Here there are no anonymous statics, and all parts of the data are kept in the `.rodata.secret`
// section.  Note, however, that you should declare the helper definitions `SECRET_STRING` and
// `SECRET_INTS` in `secret-decls` so that their sizes are known when running in verifier mode.
// Also note that normal unicode string literals can't be used here, since there is no way to force
// the content of the string to be placed in a specific section.
