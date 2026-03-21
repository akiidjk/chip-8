//! By convention, root.zig is the root source file when making a library.
const std = @import("std");
const sdl = @import("sdl").c;
const sdlPanic = @import("sdl").sdlPanic;

const FPS = 60;
const INSTR_X_FRAME = 15;
const MILLISECOND_X_FRAME = (1000 / FPS);

const Chip8 = struct {
    running: bool = false,
    opcode: u16 = 0,
    memory: [4096]u8, // 4KB
    pc: u16 = 0x200,
    I: u16 = 0,
    V: [16]u8,

    stack: [16]u16,
    sp: u16 = 0,

    gfx: [64 * 32]u8,

    delayTimer: u8 = 0,
    soundTimer: u8 = 0,

    key: [16]u8,

    draw: bool,

    renderer: *sdl.SDL_Renderer,

    setCarry: bool,
    carryValue: u1,
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

// ------------ Core functions ------------

pub fn run(window: *sdl.SDL_Window, rom: []u8) !void {
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();

    const renderer = sdl.SDL_CreateRenderer(window, -1, sdl.SDL_RENDERER_ACCELERATED) orelse sdlPanic();
    defer _ = sdl.SDL_DestroyRenderer(renderer);

    var chip8: Chip8 = try init(rom, renderer);
    // print_memory(chip8);
    // print_stack(chip8);
    chip8.running = true;

    var i: u32 = 0; //debug
    var ins_counter: u32 = 0;

    _ = sdl.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xFF);
    sdl.SDL_RenderPresent(renderer);
    _ = sdl.SDL_RenderClear(renderer);

    while (chip8.running) {
        const startFrameTime: u32 = sdl.SDL_GetTicks();
        inputHandling(&chip8);

        while (ins_counter < INSTR_X_FRAME) : (ins_counter += 1) { // INSTRUCTION RUNNER
            if (chip8.setCarry) {
                chip8.V[0xF] = chip8.carryValue;
                chip8.setCarry = false;
            }

            chip8.opcode = fetch(chip8);
            printRegisters(chip8);
            // printKeysStatus(chip8);
            decodeAndExec(&chip8);

            i += 1; // debug
            i = 0;
            if (i == 1000) { // debug
                return;
            }
        }

        //Delay
        if (ins_counter >= INSTR_X_FRAME) {
            if (chip8.delayTimer > 0) chip8.delayTimer -= 1;
            if (chip8.soundTimer > 0) chip8.soundTimer -= 1;
            ins_counter = 0;
        }

        // RENDER
        if (chip8.draw) {
            draw(chip8);
            chip8.draw = false;
        }

        const frameDuration: u32 = sdl.SDL_GetTicks() - startFrameTime;
        if (frameDuration < MILLISECOND_X_FRAME) {
            sdl.SDL_Delay(MILLISECOND_X_FRAME - frameDuration);
        }

        std.Thread.sleep(1000000000 / 120); // Small sleep
    }

    return;
}

fn inputHandling(chip8: *Chip8) void {
    var e: sdl.SDL_Event = undefined;
    while (sdl.SDL_PollEvent(&e) != 0) {
        if (e.type == sdl.SDL_QUIT) {
            chip8.running = false;
            break;
        }
        if (e.type == sdl.SDL_KEYDOWN or e.type == sdl.SDL_KEYUP) {
            const pressed: u8 = if (e.type == sdl.SDL_KEYDOWN) 1 else 0;
            switch (e.key.keysym.sym) {
                sdl.SDLK_1 => chip8.key[0x1] = pressed,
                sdl.SDLK_2 => chip8.key[0x2] = pressed,
                sdl.SDLK_3 => chip8.key[0x3] = pressed,
                sdl.SDLK_4 => chip8.key[0xC] = pressed,

                sdl.SDLK_q => chip8.key[0x4] = pressed,
                sdl.SDLK_w => chip8.key[0x5] = pressed,
                sdl.SDLK_e => chip8.key[0x6] = pressed,
                sdl.SDLK_r => chip8.key[0xD] = pressed,

                sdl.SDLK_a => chip8.key[0x7] = pressed,
                sdl.SDLK_s => chip8.key[0x8] = pressed,
                sdl.SDLK_d => chip8.key[0x9] = pressed,
                sdl.SDLK_f => chip8.key[0xE] = pressed,

                sdl.SDLK_z => chip8.key[0xA] = pressed,
                sdl.SDLK_x => chip8.key[0x0] = pressed,
                sdl.SDLK_c => chip8.key[0xB] = pressed,
                sdl.SDLK_v => chip8.key[0xF] = pressed,
                else => {},
            }
        }
    }
}

fn fetch(chip8: Chip8) u16 {
    const high: u16 = @intCast(chip8.memory[@intCast(chip8.pc)]);
    const low: u16 = @intCast(chip8.memory[@intCast(chip8.pc + 1)]);
    return (high << 8) | low;
}

fn draw(chip8: Chip8) void {
    const tex: ?*sdl.SDL_Texture = sdl.SDL_CreateTexture(chip8.renderer, sdl.SDL_PIXELFORMAT_RGBA8888, sdl.SDL_TEXTUREACCESS_STREAMING, // CPU writes to it every frame
        64, 32);

    var pixels: [64 * 32]u32 = undefined;
    var i: usize = 0;
    while (i < 64 * 32) : (i += 1) {
        pixels[i] = if (chip8.gfx[i] == 1) 0xFFFFFFFF else 0x000000FF;
    }
    _ = sdl.SDL_UpdateTexture(tex, null, &pixels, 64 * @sizeOf(u32));

    _ = sdl.SDL_RenderCopy(chip8.renderer, tex, null, null); // NULL dst = stretch to fill window
    _ = sdl.SDL_RenderPresent(chip8.renderer);
}

fn decodeAndExec(chip8: *Chip8) void {
    const opcode: u16 = chip8.opcode;
    switch (opcode & 0xF000) {
        0x0000 => { // Flow / SYS family
            switch (opcode & 0xF0FF) {
                0x00E0 => {
                    op00e0(chip8);
                },
                0x00EE => {
                    op00ee(chip8);
                },
                0x0000 => {
                    op0nnn(chip8);
                },
                else => {
                    std.debug.print("Unknown opcode: 0x{x:0>4}\n", .{opcode});
                    // Advance PC to avoid getting stuck on unknown opcode
                    chip8.running = false;
                    chip8.pc += 2;
                },
            }
        },
        0x1000 => { // 1NNN: jump to address NNN
            op1nnn(chip8);
        },
        0x2000 => { // 2NNN: call subroutine to NNN
            op2nnn(chip8);
        },
        0x3000 => { // 3XNN: Skips the next instruction if VX equals NN (usually the next instruction is a jump to skip a code block)
            op3xkk(chip8);
        },
        0x4000 => { // 4XNN: Skips the next instruction if VX does not equal NN (usually the next instruction is a jump to skip a code block).
            op4xkk(chip8);
        },
        0x5000 => { // 5XY0: Skips the next instruction if VX equals VY (usually the next instruction is a jump to skip a code block).
            op5xy0(chip8);
        },
        0x6000 => { // 6XKK: set VX = KK
            op6xkk(chip8);
        },
        0x7000 => { // 7XKK: add KK to VX
            op7xkk(chip8);
        },
        0x8000 => {
            switch (opcode & 0xF00F) {
                0x8001 => {
                    op_8xy1(chip8);
                },
                0x8002 => {
                    op_8xy2(chip8);
                },
                0x8003 => {
                    op_8xy3(chip8);
                },
                0x8004 => {
                    op_8xy4(chip8);
                },
                0x8005 => {
                    op_8xy5(chip8);
                },
                0x8006 => {
                    op_8xy6(chip8);
                },
                0x8007 => {
                    op_8xy7(chip8);
                },
                0x800E => {
                    op_8xye(chip8);
                },
                0x8000 => {
                    op_8xy0(chip8);
                },
                else => {
                    std.debug.print("Unknown opcode: 0x{x:0>4}\n", .{opcode});
                    // Advance PC to avoid getting stuck on unknown opcode
                    chip8.running = false;
                    chip8.pc += 2;
                },
            }
        },
        0x9000 => { // 9XY0: Skips the next instruction if VX not equals VY (usually the next instruction is a jump to skip a code block).
            op9xy0(chip8);
        },
        0xA000 => { // ANNN: set I = NNN
            opannn(chip8);
        },
        0xD000 => { // DXYN: draw sprite
            opdxyn(chip8);
        },
        0xE000 => { // Keys
            switch (opcode & 0xF0FF) {
                0xE09E => {
                    opex9e(chip8);
                },
                0xE0A1 => {
                    opexa1(chip8);
                },
                else => {
                    std.debug.print("Unknown opcode: 0x{x:0>4}\n", .{opcode});
                    // Advance PC to avoid getting stuck on unknown opcode
                    chip8.running = false;
                    chip8.pc += 2;
                },
            }
        },
        0xF000 => {
            switch (opcode & 0xF0FF) {
                0xF007 => {
                    op_fx07(chip8);
                },
                // 0xF00A => {},
                0xF015 => {
                    op_fx15(chip8);
                },
                // 0xF018 => {},
                0xF01E => {
                    op_fx1e(chip8);
                },
                // 0xF029 => {},
                0xF033 => {
                    op_fx33(chip8);
                },
                0xF055 => {
                    op_fx55(chip8);
                },
                0xF065 => {
                    op_fx65(chip8);
                },
                else => {
                    std.debug.print("Unknown opcode: 0x{x:0>4}\n", .{opcode});
                    // Advance PC to avoid getting stuck on unknown opcode
                    chip8.running = false;
                    chip8.pc += 2;
                },
            }
        },
        else => {
            std.debug.print("Unknown opcode: 0x{x:0>4}\n", .{opcode});
            // Advance PC to avoid getting stuck on unknown opcode
            chip8.running = false;
            chip8.pc += 2;
        },
    }
}

// Init function
fn init(rom: []u8, renderer: *sdl.SDL_Renderer) !Chip8 {
    var chip8: Chip8 = .{ .memory = undefined, .V = undefined, .stack = undefined, .gfx = undefined, .key = undefined, .pc = 0x200, .I = 0, .draw = false, .opcode = 0, .delayTimer = 0, .running = false, .soundTimer = 0, .sp = 0, .renderer = renderer, .setCarry = false, .carryValue = 0 };

    @memset(&chip8.memory, 0);
    @memset(&chip8.V, 0);
    @memset(&chip8.stack, 0);
    @memset(&chip8.gfx, 0);
    @memset(&chip8.key, 0);

    // Load fonts
    @memcpy(chip8.memory[0..][0..FONT.len], &FONT);

    // Load rom
    @memcpy(chip8.memory[0x200 .. 0x200 + rom.len], rom);

    return chip8;
}

// ------------ Handlers ------------
fn op00e0(chip8: *Chip8) void {
    @memset(&chip8.gfx, 0);
    chip8.draw = true;
    chip8.pc += 2;
}
// POP
fn op00ee(chip8: *Chip8) void {
    chip8.sp -= 1;
    chip8.pc = chip8.stack[chip8.sp];

    // Debug info: report stack pointer change and popped return address
    const prev_sp: u16 = chip8.sp + 1;
    const ret_addr: u16 = chip8.pc;
    std.debug.print(
        "op00ee: POP: SP 0x{x:0>2} -> 0x{x:0>2}, popped addr = 0x{x:0>4}\n",
        .{ prev_sp, chip8.sp, ret_addr },
    );
}
fn op0nnn(chip8: *Chip8) void {
    _ = chip8;
}
fn op1nnn(chip8: *Chip8) void {
    chip8.pc = chip8.opcode & 0x0FFF;
}
// PUSH
fn op2nnn(chip8: *Chip8) void {
    const return_addr: u16 = chip8.pc + 2; // Save current address + 2
    const target: u16 = chip8.opcode & 0x0FFF; // Destination address
    const old_sp: u16 = chip8.sp;

    chip8.stack[chip8.sp] = return_addr; // Save in the current stack position the return address
    chip8.sp += 1; // Increment the stack pointer

    chip8.pc = target; // Set the address

    std.debug.print(
        "op_2nnn: CALL to 0x{x:0>3}, return to 0x{x:0>3}, SP: 0x{x:0>2} -> 0x{x:0>2}\n",
        .{ target, return_addr, old_sp, chip8.sp },
    );
}
fn op3xkk(chip8: *Chip8) void {
    const index_reg = (chip8.opcode & 0x0F00) >> 8;
    const constant_8 = (chip8.opcode & 0x00FF);

    std.debug.print(
        "op3xkk: V{d}=0x{x:0>3} ?= 0x{x:0>3}  PC=0x{x:0>3}\n",
        .{ index_reg, chip8.V[index_reg], constant_8, chip8.pc },
    );

    if (chip8.V[index_reg] == constant_8) {
        chip8.pc += 4;
        std.debug.print("  -> equal, skipping next instruction. New PC=0x{x:0>3}\n", .{chip8.pc});
    } else {
        chip8.pc += 2;
        std.debug.print("  -> not equal, advance. New PC=0x{x:0>3}\n", .{chip8.pc});
    }
}
fn op4xkk(chip8: *Chip8) void {
    const index_reg = (chip8.opcode & 0x0F00) >> 8;
    const constant_8 = (chip8.opcode & 0x00FF);

    std.debug.print(
        "op4xkk: V{d}=0x{x:0>3} != 0x{x:0>3}?  PC=0x{x:0>3}\n",
        .{ index_reg, chip8.V[index_reg], constant_8, chip8.pc },
    );

    if (chip8.V[index_reg] != constant_8) {
        chip8.pc += 4;
        std.debug.print("  -> not equal, skipping next instruction. New PC=0x{x:0>3}\n", .{chip8.pc});
    } else {
        chip8.pc += 2;
        std.debug.print("  -> equal, advance. New PC=0x{x:0>3}\n", .{chip8.pc});
    }
}
fn op5xy0(chip8: *Chip8) void {
    const x = (chip8.opcode & 0x0F00) >> 8;
    const y = (chip8.opcode & 0x00F0) >> 4;

    std.debug.print(
        "op5xy0: V{d}=0x{x:0>3} == V{d}=0x{x:0>3}?  PC=0x{x:0>3}\n",
        .{ x, chip8.V[x], y, chip8.V[y], chip8.pc },
    );

    if (chip8.V[x] == chip8.V[y]) {
        chip8.pc += 4;
        std.debug.print("  -> equal, skipping next instruction. New PC=0x{x:0>3}\n", .{chip8.pc});
    } else {
        chip8.pc += 2;
        std.debug.print("  -> not equal, advance. New PC=0x{x:0>3}\n", .{chip8.pc});
    }
}
fn op6xkk(chip8: *Chip8) void {
    const index_reg = (chip8.opcode & 0x0F00) >> 8;
    const value: u8 = @intCast(chip8.opcode & 0x00FF);

    std.debug.print(
        "op6xkk: Set V{d} = 0x{x:0>3} (was 0x{x:0>3})  PC=0x{x:0>3}\n",
        .{ index_reg, value, chip8.V[index_reg], chip8.pc },
    );

    chip8.V[index_reg] = value;
    chip8.pc += 2;

    std.debug.print("  -> done. New V{d}=0x{x:0>3}, PC=0x{x:0>3}\n", .{ index_reg, chip8.V[index_reg], chip8.pc });
}

fn op7xkk(chip8: *Chip8) void {
    const index_register = (chip8.opcode & 0x0F00) >> 8;
    const value: u8 = @intCast(chip8.opcode & 0x00FF);

    std.debug.print(
        "op7xkk: V{d} += 0x{x:0>3}  (was 0x{x:0>3})  PC=0x{x:0>3}\n",
        .{ index_register, value, chip8.V[index_register], chip8.pc },
    );

    chip8.V[index_register], chip8.V[0xF] = @addWithOverflow(chip8.V[index_register], value);
    chip8.pc += 2;

    std.debug.print("  -> done. New V{d}=0x{x:0>3}, PC=0x{x:0>3}\n", .{ index_register, chip8.V[index_register], chip8.pc });
}
fn op_8xy0(chip8: *Chip8) void {
    const x_reg = (chip8.opcode & 0x0F00) >> 8;
    const y_reg = (chip8.opcode & 0x00F0) >> 4;

    std.debug.print(
        "op_8xy0: V{d} = V{d}  (0x{x:0>3} -> 0x{x:0>3})  PC=0x{x:0>3}\n",
        .{ x_reg, y_reg, chip8.V[y_reg], chip8.V[x_reg], chip8.pc },
    );

    chip8.V[x_reg] = chip8.V[y_reg];
    chip8.pc += 2;

    std.debug.print("  -> done. V{d}=0x{x:0>3}, PC=0x{x:0>3}\n", .{ x_reg, chip8.V[x_reg], chip8.pc });
}
fn op_8xy1(chip8: *Chip8) void {
    const x_reg = (chip8.opcode & 0x0F00) >> 8;
    const y_reg = (chip8.opcode & 0x00F0) >> 4;

    std.debug.print(
        "op_8xy1: V{d} |= V{d}  (0x{x:0>3} |= 0x{x:0>3})  PC=0x{x:0>3}\n",
        .{ x_reg, y_reg, chip8.V[x_reg], chip8.V[y_reg], chip8.pc },
    );

    chip8.V[x_reg] |= chip8.V[y_reg];
    chip8.pc += 2;

    std.debug.print("  -> done. V{d}=0x{x:0>3}, PC=0x{x:0>3}\n", .{ x_reg, chip8.V[x_reg], chip8.pc });
}
fn op_8xy2(chip8: *Chip8) void {
    const x_reg = (chip8.opcode & 0x0F00) >> 8;
    const y_reg = (chip8.opcode & 0x00F0) >> 4;

    std.debug.print(
        "op_8xy2: V{d} &= V{d}  (0x{x:0>3} &= 0x{x:0>3})  PC=0x{x:0>3}\n",
        .{ x_reg, y_reg, chip8.V[x_reg], chip8.V[y_reg], chip8.pc },
    );

    chip8.V[x_reg] &= chip8.V[y_reg];
    chip8.pc += 2;

    std.debug.print("  -> done. V{d}=0x{x:0>3}, PC=0x{x:0>3}\n", .{ x_reg, chip8.V[x_reg], chip8.pc });
}
fn op_8xy3(chip8: *Chip8) void {
    const x_reg = (chip8.opcode & 0x0F00) >> 8;
    const y_reg = (chip8.opcode & 0x00F0) >> 4;

    std.debug.print(
        "op_8xy3: V{d} ^= V{d}  (0x{x:0>3} ^= 0x{x:0>3})  PC=0x{x:0>3}\n",
        .{ x_reg, y_reg, chip8.V[x_reg], chip8.V[y_reg], chip8.pc },
    );

    chip8.V[x_reg] ^= chip8.V[y_reg];
    chip8.pc += 2;

    std.debug.print("  -> done. V{d}=0x{x:0>3}, PC=0x{x:0>3}\n", .{ x_reg, chip8.V[x_reg], chip8.pc });
}
fn op_8xy4(chip8: *Chip8) void {
    const x_reg = (chip8.opcode & 0x0F00) >> 8;
    const y_reg = (chip8.opcode & 0x00F0) >> 4;

    std.debug.print(
        "op_8xy4: V{d} += V{d}  (0x{x:0>3} + 0x{x:0>3})  PC=0x{x:0>3}\n",
        .{ x_reg, y_reg, chip8.V[x_reg], chip8.V[y_reg], chip8.pc },
    );

    const X: u16 = @intCast(chip8.V[x_reg]);
    const Y: u16 = @intCast(chip8.V[y_reg]);
    chip8.carryValue = if (X + Y > 0xFF) 1 else 0;
    chip8.setCarry = true;
    chip8.V[x_reg], _ = @addWithOverflow(chip8.V[x_reg], chip8.V[y_reg]);

    chip8.pc += 2;
    std.debug.print("  -> done. V{d}=0x{x:0>3}, PC=0x{x:0>3}\n", .{ x_reg, chip8.V[x_reg], chip8.pc });
}

fn op_8xy5(chip8: *Chip8) void {
    const x_reg = (chip8.opcode & 0x0F00) >> 8;
    const y_reg = (chip8.opcode & 0x00F0) >> 4;

    std.debug.print(
        "op_8xy5: V{d} -= V{d}  (V{d}=0x{x:0>3}, V{d}=0x{x:0>3})\n",
        .{ x_reg, y_reg, x_reg, chip8.V[x_reg], y_reg, chip8.V[y_reg] },
    );

    if (chip8.V[x_reg] >= chip8.V[y_reg]) {
        chip8.carryValue = 1;
    } else {
        chip8.carryValue = 0;
    }
    chip8.setCarry = true;
    chip8.V[x_reg], _ = @subWithOverflow(chip8.V[x_reg], chip8.V[y_reg]);

    chip8.pc += 2;
    std.debug.print("V{d} now=0x{x:0>3}\n", .{ x_reg, chip8.V[x_reg] });
}
fn op_8xy6(chip8: *Chip8) void {
    const x_reg = (chip8.opcode & 0x0F00) >> 8;
    // const y_reg = (chip8.opcode & 0x00F0) >> 4;

    std.debug.print("op_8xy6: V{d}=0x{x:0>3} >> 1  PC=0x{x:0>3}\n", .{ x_reg, chip8.V[x_reg], chip8.pc });

    chip8.carryValue = @intCast(chip8.V[x_reg] & 1);
    chip8.V[x_reg] >>= 1;
    chip8.setCarry = true;

    chip8.pc += 2;

    std.debug.print("  -> done. V{d}=0x{x:0>3}, PC=0x{x:0>3}\n", .{ x_reg, chip8.V[x_reg], chip8.pc });
}
fn op_8xy7(chip8: *Chip8) void {
    const x_reg = (chip8.opcode & 0x0F00) >> 8;
    const y_reg = (chip8.opcode & 0x00F0) >> 4;

    std.debug.print(
        "op_8xy7: V{d} = V{d} - V{d}  (V{d}=0x{x:0>3}, V{d}=0x{x:0>3})  PC=0x{x:0>3}\n",
        .{ x_reg, y_reg, x_reg, x_reg, chip8.V[x_reg], y_reg, chip8.V[y_reg], chip8.pc },
    );

    if (chip8.V[y_reg] >= chip8.V[x_reg]) {
        chip8.carryValue = 1;
    } else {
        chip8.carryValue = 0;
    }
    chip8.setCarry = true;
    chip8.V[x_reg], _ = @subWithOverflow(chip8.V[y_reg], chip8.V[x_reg]);

    chip8.pc += 2;
    std.debug.print("  PC now=0x{x:0>3}\n", .{chip8.pc});
}

fn op_8xye(chip8: *Chip8) void {
    const x_reg = (chip8.opcode & 0x0F00) >> 8;

    std.debug.print("op_8xye: V{d}=0x{x:0>3} << 1  PC=0x{x:0>3}\n", .{ x_reg, chip8.V[x_reg], chip8.pc });

    chip8.V[x_reg], chip8.carryValue = @shlWithOverflow(chip8.V[x_reg], 1);
    chip8.setCarry = true;
    chip8.pc += 2;

    std.debug.print("  -> done. V{d}=0x{x:0>3}, PC=0x{x:0>3}\n", .{ x_reg, chip8.V[x_reg], chip8.pc });
}

fn op9xy0(chip8: *Chip8) void {
    const x = (chip8.opcode & 0x0F00) >> 8;
    const y = (chip8.opcode & 0x00F0) >> 4;

    std.debug.print(
        "op9xy0: V{d}=0x{x:0>3} != V{d}=0x{x:0>3}?  PC=0x{x:0>3}\n",
        .{ x, chip8.V[x], y, chip8.V[y], chip8.pc },
    );

    if (chip8.V[x] != chip8.V[y]) {
        chip8.pc += 4;
        std.debug.print("  -> not equal, skipping next instruction. New PC=0x{x:0>3}\n", .{chip8.pc});
    } else {
        chip8.pc += 2;
        std.debug.print("  -> equal, advance. New PC=0x{x:0>3}\n", .{chip8.pc});
    }
}
fn opannn(chip8: *Chip8) void {
    const address = chip8.opcode & 0x0FFF;

    std.debug.print("opannn: Set I = 0x{x:0>3} (was 0x{x:0>3})  PC=0x{x:0>3}\n", .{ address, chip8.I, chip8.pc });

    chip8.I = address;
    chip8.pc += 2;

    std.debug.print("  -> done. I=0x{x:0>3}, PC=0x{x:0>3}\n", .{ chip8.I, chip8.pc });
}
// fn op_bnnn(chip8: *Chip8) void {}
// fn op_cxkk(chip8: *Chip8) void {}

fn opdxyn(chip8: *Chip8) void {
    const witdh = 8;
    const height = chip8.opcode & 0x000F;
    const x = chip8.V[(chip8.opcode & 0x0F00) >> 8];
    const y = chip8.V[(chip8.opcode & 0x00F0) >> 4];
    var yline: u16 = 0;
    chip8.V[0xF] = 0;

    while (yline < height) : (yline += 1) {
        const pixel = chip8.memory[chip8.I + yline];
        var xline: u16 = 0;
        while (xline < witdh) : (xline += 1) {
            if ((pixel >> @intCast(7 - xline)) & 1 != 0) {
                if (chip8.gfx[(x + xline + ((y + yline) * 64))] == 1)
                    chip8.V[0xF] = 1;
                chip8.gfx[x + xline + ((y + yline) * 64)] ^= 1;
            }
        }
    }

    chip8.pc += 2;
    chip8.draw = true;
    return;
}

fn opex9e(chip8: *Chip8) void {
    const x = (chip8.opcode & 0x0F00) >> 8;
    if (chip8.key[chip8.V[x]] == 1) {
        chip8.pc += 4;
    } else {
        chip8.pc += 2;
    }
}
fn opexa1(chip8: *Chip8) void {
    const x = (chip8.opcode & 0x0F00) >> 8;
    if (chip8.key[chip8.V[x]] != 1) {
        chip8.pc += 4;
    } else {
        chip8.pc += 2;
    }
}

fn op_fx07(chip8: *Chip8) void {
    const reg_x = (chip8.opcode & 0x0F00) >> 8;
    const prev_val: u8 = chip8.V[reg_x];
    const prev_delay: u8 = chip8.delayTimer;

    chip8.V[reg_x] = chip8.delayTimer;
    chip8.pc += 2;

    std.debug.print(
        "op_fx07: V{d} = delayTimer (0x{x:0>2}) (was V{d}=0x{x:0>2})  PC=0x{x:0>4}\n",
        .{ reg_x, prev_delay, reg_x, prev_val, chip8.pc },
    );
}
// fn op_fx0a(chip8: *Chip8 ) void {}
fn op_fx15(chip8: *Chip8) void {
    const reg_x = (chip8.opcode & 0x0F00) >> 8;
    const prev_delay: u8 = chip8.delayTimer;

    chip8.delayTimer = chip8.V[reg_x];
    chip8.pc += 2;

    std.debug.print(
        "op_fx15: delayTimer = V{d} (0x{x:0>2}) (was 0x{x:0>2})  PC=0x{x:0>4}\n",
        .{ reg_x, chip8.V[reg_x], prev_delay, chip8.pc },
    );
}
// fn op_fx18(chip8: *Chip8 ) void {}
fn op_fx1e(chip8: *Chip8) void {
    const reg = (chip8.opcode & 0x0F00) >> 8;
    const old_i: u16 = chip8.I;
    const value: u16 = chip8.V[reg];

    chip8.I = old_i + value;
    chip8.pc += 2;

    std.debug.print(
        "op_fx1e: I: 0x{x:0>3} + V{d}: 0x{x:0>3} -> I: 0x{x:0>3}\n",
        .{ old_i, reg, value, chip8.I },
    );
}
// fn op_fx29(chip8: *Chip8 ) void {}
fn op_fx33(chip8: *Chip8) void {
    const reg_target = (chip8.opcode & 0x0F00) >> 8;
    const value_bcd = chip8.V[reg_target];

    const ones: u8 = @intCast(value_bcd % 10);
    const tens: u8 = @intCast((value_bcd / 10) % 10);
    const hundreds: u8 = @intCast((value_bcd / 100) % 10);

    chip8.memory[chip8.I + 2] = ones;
    chip8.memory[chip8.I + 1] = tens;
    chip8.memory[chip8.I] = hundreds;

    std.debug.print(
        "op_fx33: V{d}=0x{x:0>3} -> mem[0x{x:0>3}]= {d}, mem[0x{x:0>3}+1]= {d}, mem[0x{x:0>3}+2]= {d}\n",
        .{ reg_target, value_bcd, chip8.I, hundreds, chip8.I, tens, chip8.I, ones },
    );

    chip8.pc += 2;
}
fn op_fx55(chip8: *Chip8) void {
    const final_reg = (chip8.opcode & 0x0F00) >> 8;
    var i: usize = 0;

    std.debug.print(
        "op_fx55: Store V0..V{d} to memory starting at I=0x{x:0>3}\n",
        .{ final_reg, chip8.I },
    );

    while (i <= final_reg) : (i += 1) {
        chip8.memory[chip8.I + i] = @intCast(chip8.V[i]);
        std.debug.print(
            "  mem[0x{x:0>3}+{d}] = 0x{x:0>3}\n",
            .{ chip8.I, i, chip8.memory[chip8.I + i] },
        );
    }
    chip8.I += (final_reg + 1);
    chip8.pc += 2;
}
fn op_fx65(chip8: *Chip8) void {
    const final_reg = (chip8.opcode & 0x0F00) >> 8;
    var i: usize = 0;

    std.debug.print(
        "op_fx65: Load V0..V{d} from memory starting at I=0x{x:0>3}\n",
        .{ final_reg, chip8.I },
    );

    while (i <= final_reg) : (i += 1) {
        chip8.V[i] = chip8.memory[chip8.I + i];
        std.debug.print(
            "  V{d} = 0x{x:0>3}\n",
            .{ i, chip8.V[i] },
        );
    }

    chip8.I += (final_reg + 1);
    chip8.pc += 2;
}

// ------------ Debug shit ------------
fn printMemory(chip8: Chip8) void {
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

fn printStack(chip8: Chip8) void {
    var i: usize = 0;
    while (i < chip8.stack.len) {
        std.debug.print("0x{x:0>32}\n", .{chip8.stack[i]});
        i += 1;
    }
}

fn printRegisters(chip8: Chip8) void {
    std.debug.print("--------- Registers --------- \n", .{});
    var i: usize = 0;
    while (i < chip8.V.len) : (i += 4) {
        const r0 = chip8.V[i];
        const r1 = chip8.V[i + 1];
        const r2 = chip8.V[i + 2];
        const r3 = chip8.V[i + 3];
        std.debug.print(
            "V{d}: 0x{x:0>2}    V{d}: 0x{x:0>2}    V{d}: 0x{x:0>2}    V{d}: 0x{x:0>2}\n",
            .{ i, r0, i + 1, r1, i + 2, r2, i + 3, r3 },
        );
    }

    std.debug.print(
        "I: 0x{x:0>4}    PC: 0x{x:0>4}    SP: 0x{x:0>2}    SetCarry: {}    CarryValue: {d}\n",
        .{ chip8.I, chip8.pc, chip8.sp, chip8.setCarry, chip8.carryValue },
    );

    std.debug.print(
        "Opcode: 0x{x:0>4}    Delay: 0x{x:0>2}    Sound: 0x{x:0>2}    Draw: {s}    Running: {s}\n",
        .{
            chip8.opcode,
            chip8.delayTimer,
            chip8.soundTimer,
            if (chip8.draw) "true" else "false",
            if (chip8.running) "true" else "false",
        },
    );
}

fn printGFX(chip8: Chip8) void {
    std.debug.print("------- GFX MATRIX -------\n", .{});
    var y: usize = 0;
    while (y < 64) : (y += 1) {
        var x: usize = 0;
        while (x < 32) : (x += 1) {
            std.debug.print("{d} ", .{chip8.gfx[y * 32 + x]});
        }
        std.debug.print("\n", .{});
    }
}

fn printKeysStatus(chip8: Chip8) void {
    std.debug.print("------- KEYS MATRIX -------\n", .{});
    var y: usize = 0;
    while (y < 4) : (y += 1) {
        var x: usize = 0;
        while (x < 4) : (x += 1) {
            std.debug.print("{d} ", .{chip8.key[y * 4 + x]});
        }
        std.debug.print("\n", .{});
    }
}
