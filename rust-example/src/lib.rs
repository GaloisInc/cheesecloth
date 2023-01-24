#![cfg_attr(feature = "microram", no_std)]

extern crate alloc;

use alloc::borrow::ToOwned;

pub fn find_nth(vals: &[i32], n: usize) -> i32 {
    let mut v = vals.to_owned();
    v.sort();
    v[n]
}
