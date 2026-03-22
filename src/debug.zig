const std = @import("std");
const chip = @import("chip8.zig");
const builtin = @import("builtin");

// Source - https://stackoverflow.com/q/79880678
// Posted by freziyt223, modified by community. See post 'Timeline' for change history
// Retrieved 2026-03-22, License - CC BY-SA 4.0
pub fn Print(comptime fmt: []const u8, args: anytype) !void {
    const allocator = std.heap.smp_allocator;
    const count = std.fmt.count(fmt, args);
    const buf = try allocator.alloc(u8, count);
    defer allocator.free(buf);
    var stdout_writer = std.fs.File.stdout().writer(buf);
    const stdout = &stdout_writer.interface;
    try stdout.print(fmt, args);
    try stdout.flush();
}

// ------------ Debug shit ------------
pub fn printMemory(memory: []u8) !void {
    if (builtin.mode != .Debug) {
        return;
    }

    var i: usize = 0;
    var j: usize = 0;
    while (i < memory.len / 8) : (i += 1) {
        try Print("0x{x:0>4} ", .{i * 8});
        j = 0;
        while (j < 8) : (j += 2) { // print row
            try Print("\x1b[97m{x:0>2}\x1b[0m \x1b[90m{x:0>2}\x1b[0m ", .{ memory[i * 8 + j], memory[i * 8 + (j + 1)] });
        }
        try Print("\n", .{});
    }
}

pub fn printStack(stack: []u16) !void {
    if (builtin.mode != .Debug) {
        return;
    }
    var i: usize = 0;
    while (i < stack.len) {
        try Print("{x}: 0x{x:0>4}\n", .{ i, stack[i] });
        i += 1;
    }
}

pub fn printVRegisters(V: []u8) !void {
    if (builtin.mode != .Debug) {
        return;
    }
    var i: usize = 0; // 4x4
    while (i < V.len) : (i += 4) {
        const r0 = V[i];
        const r1 = V[i + 1];
        const r2 = V[i + 2];
        const r3 = V[i + 3];
        try Print(
            "V{d}: 0x{x:0>2}    V{d}: 0x{x:0>2}    V{d}: 0x{x:0>2}    V{d}: 0x{x:0>2}\n",
            .{ i, r0, i + 1, r1, i + 2, r2, i + 3, r3 },
        );
    }
}

pub fn printOtherRegisters(I: u16, PC: u16, SP: u16) !void {
    if (builtin.mode != .Debug) {
        return;
    }
    try Print(
        "I: 0x{x:0>4}    PC: 0x{x:0>4}    SP: 0x{x:0>2}\n",
        .{ I, PC, SP },
    );
}

pub fn printInternalStatus(opcode: u16, delayTimer: u16, soundTimer: u16, isDraw: bool) !void {
    if (builtin.mode != .Debug) {
        return;
    }
    try Print(
        "Opcode: 0x{x:0>4}    Delay: 0x{x:0>2}    Sound: 0x{x:0>2}    Draw: {s}\n",
        .{
            opcode,
            delayTimer,
            soundTimer,
            if (isDraw) "true" else "false",
        },
    );
}

pub fn printGFX(gfx: []u8) !void {
    if (builtin.mode != .Debug) {
        return;
    }
    var y: usize = 0;
    while (y < 64) : (y += 1) {
        var x: usize = 0;
        while (x < 32) : (x += 1) {
            try Print("{d} ", .{gfx[y * 32 + x]});
        }
        try Print("\n", .{});
    }
}

fn printKeysState(key: []8) !void {
    if (builtin.mode != .Debug) {
        return;
    }
    var y: usize = 0;
    while (y < 4) : (y += 1) {
        var x: usize = 0;
        while (x < 4) : (x += 1) {
            try Print("{d} ", .{key[y * 4 + x]});
        }
        try Print("\n", .{});
    }
}

pub fn printChip8State(chip8: *chip.Chip8) !void {
    if (builtin.mode != .Debug) {
        return;
    }
    try Print(
        "\x1b[92mCycles: {d}\x1b[0m\n\n",
        .{chip8.cycles},
    );

    try Print("\x1b[94m-- Flow registers --\x1b[0m\n", .{});
    try Print(
        "\x1b[97mI: 0x{x:0>4}\x1b[0m   \x1b[97mSP: 0x{x:0>2}\x1b[0m   \x1b[97mDT: 0x{x:0>2}\x1b[0m   \x1b[97mST: 0x{x:0>2}\x1b[0m\n",
        .{ chip8.I, chip8.SP, chip8.delayTimer, chip8.soundTimer },
    );

    try Print(
        "\x1b[97mPC: 0x{x:0>4}\x1b[0m   \x1b[97mOpcode: 0x{x:0>4}\x1b[0m\n",
        .{ chip8.PC, chip8.opcode },
    );

    // Divider
    try Print("\n", .{});

    try Print("\x1b[96m-- Registers --\x1b[0m\n", .{});
    _ = try printVRegisters(&chip8.V);

    try Print("\n\x1b[93m-- Stack --\x1b[0m\n", .{});
    _ = try printStack(&chip8.stack);

    try Print("\n\x1b[95m-- Memory (slice around PC) --\x1b[0m\n", .{});
    // compute a small window around PC for readability
    const mem = chip8.memory[0..];
    const pc_index: usize = @intCast(chip8.PC);
    const window_start = if (pc_index >= 8) pc_index - 8 else 0;
    const window_end = if (window_start + 64 <= mem.len) window_start + 64 else mem.len;
    try printMemory(mem[window_start..window_end]);

    try Print("\n=========================================================================\n", .{});
}
