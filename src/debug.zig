const std = @import("std");

// ------------ Debug shit ------------
pub fn printMemory(memory: []u8) void {
    var i: usize = 0;
    while (i < memory.len) {
        var str1: [8]u8 = undefined;
        @memcpy(&str1, memory[i..(i + 8)]);
        var str2: [8]u8 = undefined;
        @memcpy(&str2, memory[(i + 8)..(i + 16)]);
        const hex1 = std.fmt.bytesToHex(str1, .lower);
        const hex2 = std.fmt.bytesToHex(str2, .lower);
        std.debug.print("0x{x:0>3}: 0x{s} 0x{s}\n", .{ i, hex1, hex2 });
        i += 16;
    }
}

pub fn printStack(stack: []u16) void {
    var i: usize = 0;
    while (i < stack.len) {
        std.debug.print("0x{x:0>32}\n", .{stack[i]});
        i += 1;
    }
}

pub fn printVRegisters(V: []u8) void {
    std.debug.print("---------V Registers --------- \n", .{});
    var i: usize = 0;
    while (i < V.len) : (i += 4) {
        const r0 = V[i];
        const r1 = V[i + 1];
        const r2 = V[i + 2];
        const r3 = V[i + 3];
        std.debug.print(
            "V{d}: 0x{x:0>2}    V{d}: 0x{x:0>2}    V{d}: 0x{x:0>2}    V{d}: 0x{x:0>2}\n",
            .{ i, r0, i + 1, r1, i + 2, r2, i + 3, r3 },
        );
    }
}

pub fn printOtherRegisters(I: u16, PC: u16, SP: u16) void {
    std.debug.print("--------- Others Registers --------- \n", .{});

    std.debug.print(
        "I: 0x{x:0>4}    PC: 0x{x:0>4}    SP: 0x{x:0>2}\n",
        .{ I, PC, SP },
    );
}

pub fn printInternalStatus(opcode: u16, delayTimer: u16, soundTimer: u16, isDraw: bool) void {
    std.debug.print("--------- Current Status --------- \n", .{});
    std.debug.print(
        "Opcode: 0x{x:0>4}    Delay: 0x{x:0>2}    Sound: 0x{x:0>2}    Draw: {s}\n",
        .{
            opcode,
            delayTimer,
            soundTimer,
            if (isDraw) "true" else "false",
        },
    );
}

fn printGFX(gfx: []u8) void {
    std.debug.print("------- GFX MATRIX -------\n", .{});
    var y: usize = 0;
    while (y < 64) : (y += 1) {
        var x: usize = 0;
        while (x < 32) : (x += 1) {
            std.debug.print("{d} ", .{gfx[y * 32 + x]});
        }
        std.debug.print("\n", .{});
    }
}

fn printKeysStatus(key: []8) void {
    std.debug.print("------- KEYS MATRIX -------\n", .{});
    var y: usize = 0;
    while (y < 4) : (y += 1) {
        var x: usize = 0;
        while (x < 4) : (x += 1) {
            std.debug.print("{d} ", .{key[y * 4 + x]});
        }
        std.debug.print("\n", .{});
    }
}
