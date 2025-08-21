// Keep everything C-compatible and unmangled
#[unsafe(no_mangle)]
pub extern "C" fn add_integers(a: i32, b: i32) -> i32 {
    a + b
}

#[unsafe(no_mangle)]
pub extern "C" fn subtract_integers(a: i32, b: i32) -> i32 {
    a - b
}

#[unsafe(no_mangle)]
pub extern "C" fn multiply_integers(a: i32, b: i32) -> i32 {
    a * b
}

#[unsafe(no_mangle)]
pub extern "C" fn divide_integers(a: i32, b: i32) -> i32 {
    // assume b != 0
    a / b
}
