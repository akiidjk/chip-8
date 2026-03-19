//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

const Chip8 = struct {
    running: bool,
    opcode: u16,
    memory: []u8, // 4KB (4096 bytes)
    PC: u16,
    I: u16,
    reg: struct {
        r0: u8,
        r1: u8,
        r2: u8,
        r3: u8,
        r4: u8,
        r5: u8,
        r6: u8,
        r7: u8,
        r8: u8,
        r9: u8,
        ra: u8,
        rb: u8,
        rc: u8,
        rd: u8,
        re: u8,
        rf: u8,
    },
};

const FONT = [_]u8{
    0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
    0x20, 0x60, 0x20, 0x20, 0x70, // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
    0x90, 0x90, 0xF0, 0x10, 0x10, // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
    0xF0, 0x10, 0x20, 0x40, 0x40, // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90, // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
    0xF0, 0x80, 0x80, 0x80, 0xF0, // C
    0xE0, 0x90, 0x90, 0x90, 0xE0, // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
    0xF0, 0x80, 0xF0, 0x80, 0x80, // F
};

pub fn bufferedPrint() !void {
    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try stdout.flush(); // Don't forget to flush!
}

pub fn run(rom: []u8) !void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const chip8: Chip8 = .{ .running = true, .opcode = 0x00, .memory = try allocator.alloc(u8, 4096), .I = 0, .PC = 0, .reg = {} };

    init(chip8, rom);

    while (chip8.running) {
        // Decode
        // Fetch
        //Execute
    }
}

fn init(chip8: Chip8, rom: []u8) void {
    @memcpy(chip8.memory, rom);
}

// fn decode(chip8: Chip8) void {}
