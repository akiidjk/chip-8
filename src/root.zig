//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const sdl = @import("sdl").c;
const sdlPanic = @import("sdl").sdlPanic;

const Chip8 = struct {
    running: bool = false,
    opcode: u16 = 0,
    memory: [4096]u8, // 4KB (4096 bytes)
    pc: u16 = 0x200,
    i: u16 = 0,
    v: [16]u16, // 16 registri da 16 bit

    stack: [16]u16, // 16
    sp: u16 = 0,

    gfx: [64 * 32]u8, // 64 * 32

    delay_timer: u8 = 0,
    sound_time: u8 = 0,

    key: [16]u8, // 16

    draw: bool,

    render: *sdl.SDL_Renderer,
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

const OpHandler = *const fn (*Chip8) void;

const OpcodeDesc = struct {
    mask: u16,
    value: u16,
    handler: OpHandler,
};

// opcode & mask = value
const opcode_table = [_]OpcodeDesc{
    // 0x00E0 and 0x00EE are specific, 0x0NNN (SYS) is generic
    .{ .mask = 0xF0FF, .value = 0x00E0, .handler = op_00e0 },
    // .{ .mask = 0xF0FF, .value = 0x00EE, .handler = op_00ee },
    // .{ .mask = 0xF000, .value = 0x0000, .handler = op_0nnn },

    .{ .mask = 0xF000, .value = 0x1000, .handler = op_1nnn },
    // .{ .mask = 0xF000, .value = 0x2000, .handler = op_2nnn },
    // .{ .mask = 0xF000, .value = 0x3000, .handler = op_3xkk },
    // .{ .mask = 0xF000, .value = 0x4000, .handler = op_4xkk },

    // 5XY0 and 9XY0 need to check low nibble == 0
    // .{ .mask = 0xF00F, .value = 0x5000, .handler = op_5xy0 },

    .{ .mask = 0xF000, .value = 0x6000, .handler = op_6xkk },
    .{ .mask = 0xF000, .value = 0x7000, .handler = op_7xkk },

    // 8XY_ family based on lowest nibble
    // .{ .mask = 0xF00F, .value = 0x8000, .handler = op_8xy0 },
    // .{ .mask = 0xF00F, .value = 0x8001, .handler = op_8xy1 },
    // .{ .mask = 0xF00F, .value = 0x8002, .handler = op_8xy2 },
    // .{ .mask = 0xF00F, .value = 0x8003, .handler = op_8xy3 },
    // .{ .mask = 0xF00F, .value = 0x8004, .handler = op_8xy4 },
    // .{ .mask = 0xF00F, .value = 0x8005, .handler = op_8xy5 },
    // .{ .mask = 0xF00F, .value = 0x8006, .handler = op_8xy6 },
    // .{ .mask = 0xF00F, .value = 0x8007, .handler = op_8xy7 },
    // .{ .mask = 0xF00F, .value = 0x800E, .handler = op_8xye },

    // .{ .mask = 0xF00F, .value = 0x9000, .handler = op_9xy0 },

    .{ .mask = 0xF000, .value = 0xA000, .handler = op_annn },
    // .{ .mask = 0xF000, .value = 0xB000, .handler = op_bnnn },
    // .{ .mask = 0xF000, .value = 0xC000, .handler = op_cxkk },
    .{ .mask = 0xF000, .value = 0xD000, .handler = op_dxyn },

    // EX__ key opcodes
    // .{ .mask = 0xF0FF, .value = 0xE09E, .handler = op_ex9e },
    // .{ .mask = 0xF0FF, .value = 0xE0A1, .handler = op_exa1 },

    // FX__ family (timers, memory, sound, keys, I operations)
    // .{ .mask = 0xF0FF, .value = 0xF007, .handler = op_fx07 },
    // .{ .mask = 0xF0FF, .value = 0xF00A, .handler = op_fx0a },
    // .{ .mask = 0xF0FF, .value = 0xF015, .handler = op_fx15 },
    // .{ .mask = 0xF0FF, .value = 0xF018, .handler = op_fx18 },
    // .{ .mask = 0xF0FF, .value = 0xF01E, .handler = op_fx1e },
    // .{ .mask = 0xF0FF, .value = 0xF029, .handler = op_fx29 },
    // .{ .mask = 0xF0FF, .value = 0xF033, .handler = op_fx33 },
    // .{ .mask = 0xF0FF, .value = 0xF055, .handler = op_fx55 },
    // .{ .mask = 0xF0FF, .value = 0xF065, .handler = op_fx65 },
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

// Main functions
pub fn run(window: *sdl.SDL_Window, rom: []u8) !void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();

    const renderer = sdl.SDL_CreateRenderer(window, -1, sdl.SDL_RENDERER_ACCELERATED) orelse sdlPanic();
    defer _ = sdl.SDL_DestroyRenderer(renderer);

    var chip8: Chip8 = try init(rom, renderer);
    std.debug.print("0x{x}\n", .{chip8.pc});
    // print_memory(chip8);
    // print_stack(chip8);
    chip8.running = true;

    var i: u32 = 0; //debug

    while (chip8.running) {
        var ev: sdl.SDL_Event = undefined;
        chip8.opcode = fetch(chip8);
        print_registers(chip8);

        decodeAndExec(&chip8);

        i += 1; // debug
        if (i == 0xFFF) { // debug
            return;
        }

        if (chip8.draw) {
            _ = sdl.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xFF);
            sdl.SDL_RenderPresent(renderer);
            _ = sdl.SDL_RenderClear(renderer);
            chip8.draw = false;
        }

        while (sdl.SDL_PollEvent(&ev) != 0) {
            if (ev.type == sdl.SDL_QUIT)
                break;
        }
    }

    return;
}

fn fetch(chip8: Chip8) u16 {
    const high: u16 = @intCast(chip8.memory[@intCast(chip8.pc)]);
    const low: u16 = @intCast(chip8.memory[@intCast(chip8.pc + 1)]);
    return (high << 8) | low;
}

fn decodeAndExec(chip8: *Chip8) void {
    for (opcode_table) |desc| {
        if ((chip8.opcode & desc.mask) == desc.value) {
            desc.handler(chip8);
            return;
        }
    }
    // opcode sconosciuto → log / panic
    std.debug.print("Unknown opcode: {x:0>4}\n", .{chip8.opcode});
}

// Init function
fn init(rom: []u8, renderer: *sdl.SDL_Renderer) !Chip8 {
    var chip8: Chip8 = .{ .memory = undefined, .v = undefined, .stack = undefined, .gfx = undefined, .key = undefined, .pc = 0x200, .i = 0, .draw = false, .opcode = 0, .delay_timer = 0, .running = false, .sound_time = 0, .sp = 0, .render = renderer };
    @memset(&chip8.memory, 0);
    @memset(&chip8.v, 0);
    @memset(&chip8.stack, 0);
    @memset(&chip8.gfx, 0);
    @memset(&chip8.key, 0);

    // Load fonts
    @memcpy(chip8.memory[0..][0..FONT.len], &FONT);

    // Load rom
    @memcpy(chip8.memory[0x200 .. 0x200 + rom.len], rom);

    return chip8;
}

// Handlers
fn op_00e0(chip8: *Chip8) void {
    chip8.draw = true;
    chip8.pc += 2;
    return;
}
// fn op_00ee(chip8: *Chip8 ) void {}
// fn op_0nnn(chip8: *Chip8 ) void {}
fn op_1nnn(chip8: *Chip8) void {
    chip8.pc = chip8.opcode & 0x0FFF;
}
// fn op_2nnn(chip8: *Chip8 ) void {}
// fn op_3xkk(chip8: *Chip8 ) void {}
// fn op_4xkk(chip8: *Chip8 ) void {}
// fn op_5xy0(chip8: *Chip8 ) void {}
fn op_6xkk(chip8: *Chip8) void {
    const index_register = (chip8.opcode >> 2) & 0x0F;
    const value = chip8.opcode & 0x00FF;
    chip8.v[index_register] = value;
    chip8.pc += 2;
}
fn op_7xkk(chip8: *Chip8) void {
    const index_register = (chip8.opcode >> 2) & 0x0F;
    const value = chip8.opcode & 0x00FF;
    chip8.v[index_register] += value;
    chip8.pc += 2;
}
// fn op_8xy0(chip8: *Chip8 ) void {}
// fn op_8xy1(chip8: *Chip8 ) void {}
// fn op_8xy2(chip8: *Chip8 ) void {}
// fn op_8xy3(chip8: *Chip8 ) void {}
// fn op_8xy4(chip8: *Chip8 ) void {}
// fn op_8xy5(chip8: *Chip8 ) void {}
// fn op_8xy6(chip8: *Chip8 ) void {}
// fn op_8xy7(chip8: *Chip8 ) void {}
// fn op_8xye(chip8: *Chip8 ) void {}
// fn op_9xy0(chip8: *Chip8 ) void {}
fn op_annn(chip8: *Chip8) void {
    const address = chip8.opcode & 0x0FFF;
    chip8.i = address;
    chip8.pc += 2;
}
// fn op_bnnn(chip8: *Chip8 ) void {}
// fn op_cxkk(chip8: *Chip8 ) void {}
fn op_dxyn(chip8: *Chip8) void {
    chip8.pc += 2;
    chip8.draw = true;
    return;
}
// fn op_ex9e(chip8: *Chip8 ) void {}
// fn op_exa1(chip8: *Chip8 ) void {}
// fn op_fx07(chip8: *Chip8 ) void {}
// fn op_fx0a(chip8: *Chip8 ) void {}
// fn op_fx15(chip8: *Chip8 ) void {}
// fn op_fx18(chip8: *Chip8 ) void {}
// fn op_fx1e(chip8: *Chip8 ) void {}
// fn op_fx29(chip8: *Chip8 ) void {}
// fn op_fx33(chip8: *Chip8 ) void {}
// fn op_fx55(chip8: *Chip8 ) void {}
// fn op_fx65(chip8: *Chip8 ) void {}

// Debug shit
fn print_memory(chip8: Chip8) void {
    var i: usize = 0;
    while (i < chip8.memory.len) {
        var str1: [8]u8 = undefined;
        @memcpy(&str1, chip8.memory[i..(i + 8)]);
        var str2: [8]u8 = undefined;
        @memcpy(&str2, chip8.memory[(i + 8)..(i + 16)]);
        const hex1 = std.fmt.bytesToHex(str1, .lower);
        const hex2 = std.fmt.bytesToHex(str2, .lower);
        std.debug.print("0x{x:0>3}: 0x{s} 0x{s}\n", .{ i, hex1, hex2 });
        i += 16;
    }
}

fn print_stack(chip8: Chip8) void {
    var i: usize = 0;
    while (i < chip8.stack.len) {
        std.debug.print("0x{x:0>32}\n", .{chip8.stack[i]});
        i += 1;
    }
}

fn print_registers(chip8: Chip8) void {
    std.debug.print("--------- Registers --------- \n", .{});
    var i: usize = 0;
    while (i < chip8.v.len) : (i += 4) {
        const r0 = chip8.v[i];
        const r1 = chip8.v[i + 1];
        const r2 = chip8.v[i + 2];
        const r3 = chip8.v[i + 3];
        std.debug.print(
            "V{d}: 0x{x:0>3}    V{d}: 0x{x:0>3}    V{d}: 0x{x:0>3}    V{d}: 0x{x:0>3}\n",
            .{ i, r0, i + 1, r1, i + 2, r2, i + 3, r3 },
        );
    }

    std.debug.print(
        "I: 0x{x:0>3}    PC: 0x{x:0>3}    SP: 0x{x:0>2}\n",
        .{ chip8.i, chip8.pc, chip8.sp },
    );

    std.debug.print(
        "Opcode: 0x{x:0>4}    Delay: 0x{x:0>2}    Sound: 0x{x:0>2}    Draw: {s}    Running: {s}\n",
        .{
            chip8.opcode,
            chip8.delay_timer,
            chip8.sound_time,
            if (chip8.draw) "true" else "false",
            if (chip8.running) "true" else "false",
        },
    );
}
