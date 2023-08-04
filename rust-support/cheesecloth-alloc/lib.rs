#![no_std]
extern crate alloc;

use core::ptr;
use alloc::alloc::{GlobalAlloc, Layout};

struct CheeseclothAlloc;

extern "C" {
    fn posix_memalign(ptr_out: *mut *mut u8, align: usize, size: usize) -> i32;
    fn free(ptr: *mut u8);
}

unsafe impl GlobalAlloc for CheeseclothAlloc {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        let mut ptr = ptr::null_mut();
        let ok = posix_memalign(&mut ptr, layout.align(), layout.size());
        if ok != 0 {
            return ptr::null_mut();
        }
        ptr
    }

    unsafe fn dealloc(&self, ptr: *mut u8, _layout: Layout) {
        free(ptr);
    }
}

#[global_allocator]
static ALLOC: CheeseclothAlloc = CheeseclothAlloc;
