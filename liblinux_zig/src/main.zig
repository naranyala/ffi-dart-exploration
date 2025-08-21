// lib.zig
const std = @import("std");

export fn add(a: i32, b: i32) callconv(.C) i32 {
    return a + b;
}

export fn greet() callconv(.C) [*:0]const u8 {
    return "Hello from Zig!";
}

