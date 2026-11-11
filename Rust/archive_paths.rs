//! Classify a path from libarchive before it can be used to write to disk.
#![cfg_attr(not(test), no_std)]

fn classify(path: &[u8]) -> u8 {
    if path.starts_with(b"/") {
        return 0;
    }
    let mut result = 1;
    for part in path.split(|&byte| byte == b'/') {
        match part {
            b".." => return 0,
            b"" | b"." => {}
            _ => result = 2,
        }
    }
    result
}

/// C passes the bytes from a live libarchive entry with the NUL excluded.
#[no_mangle]
pub unsafe extern "C" fn ryc0_archive_path_kind(path: *const u8, length: usize) -> u8 {
    if path.is_null() {
        return 0;
    }
    classify(unsafe { core::slice::from_raw_parts(path, length) })
}

#[cfg(not(test))]
#[panic_handler]
fn panic(_: &core::panic::PanicInfo<'_>) -> ! {
    extern "C" { fn abort() -> !; }
    unsafe { abort() }
}

#[cfg(test)]
mod tests {
    use super::classify;

    #[test]
    fn only_relative_non_traversing_paths() {
        assert_eq!(classify(b"./Payload/ryP0.app"), 2);
        assert_eq!(classify(b"foo/..bar/guest"), 2);
        assert_eq!(classify(b"././"), 1);
        for path in [b"../guest".as_slice(), b"nested/../guest", b"/guest", b"/"] {
            assert_eq!(classify(path), 0);
        }
    }
}
