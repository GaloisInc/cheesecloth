#![cfg_attr(feature = "microram", no_std)]
#![cfg_attr(feature = "microram", no_main)]
#![cfg_attr(feature = "microram", feature(default_alloc_error_handler))]
#![cfg_attr(feature = "microram", feature(lang_items))]

#[cfg(feature = "microram")] extern crate cheesecloth_alloc;
#[cfg(feature = "inline-secrets")] extern crate cheesecloth_rust_example_secrets;

use cheesecloth_rust_example::find_nth;
use cheesecloth_rust_example_secret_decls::secret_input;


#[cfg_attr(feature = "microram", no_mangle)]
pub fn main() {
    let nth = find_nth(secret_input(), 3);
    assert_eq!(nth, 10);
    answer(1);
}


// TODO: these should eventually be moved into a support library

#[cfg(feature = "microram")]
fn answer(x: usize) -> ! {
    extern "C" {
        fn __cc_answer(x: usize) -> !;
    }
    unsafe { __cc_answer(x) };
}

#[cfg(not(feature = "microram"))]
fn answer(x: usize) -> ! {
    eprintln!("ANSWER = {}", x);
    std::process::exit(0);
}

#[cfg(feature = "microram")]
#[panic_handler]
fn panic(info: &core::panic::PanicInfo) -> ! {
    extern "C" {
        fn __cc_answer(code: i32) -> !;
    }
    unsafe {
        __cc_answer(0);
    }
}

#[cfg(feature = "microram")]
#[lang = "eh_personality"]
extern "C" fn eh_personality() {}
