const std = @import("std");

const builtin = @import("builtin");

pub const default_level: std.log.Level = switch (builtin.mode) {
    .Debug => .debug,
    .ReleaseSafe => .info,
    .ReleaseFast, .ReleaseSmall => .err,
};

pub fn formatFn(comptime level: std.log.Level, comptime scope: @TypeOf(.EnumLiteral), comptime format: []const u8, args: anytype) void {
    // Time
    const ts_ms: i64 = std.time.milliTimestamp();
    const sec: i64 = @divTrunc(ts_ms, 1000);
    const ms: i64 = @mod(ts_ms, 1000);

    // Scope (add your known scopes here; provide a fallback)
    const scope_name = switch (scope) {
        .sdl => "sdl",
        .chip8 => "chip8",
        .log => "log",
        else => "unknown",
    };

    // Level strings and ANSI color codes
    const color_start = switch (level) {
        .debug => "\x1b[36m", // cyan
        .info => "\x1b[32m", // green
        .warn => "\x1b[33m", // yellow
        .err => "\x1b[31m", // red
    };
    const level_name = switch (level) {
        .debug => "DEBUG",
        .info => "INFO",
        .warn => "WARN",
        .err => "ERROR",
    };
    const color_end = "\x1b[0m";

    // Prefix: [time] [scope] LEVEL:
    // Example: 1617.123 [sdl] INFO:
    // Use std.debug.print for output to avoid recursion into std.log.*
    std.debug.print("\x1b[90m{d}.{d:03}\x1b[0m [{s}] {s}{s}{s}: ", .{ sec, ms, scope_name, color_start, level_name, color_end });

    // The user-provided message and args
    std.debug.print(format, args);

    // Terminate the log line
    std.debug.print("\n", .{});
}

pub const sdl = std.log.scoped(.sdl);
pub const chip8 = std.log.scoped(.chip8);
pub const log = std.log.scoped(.log);
