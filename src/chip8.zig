const std = @import("std");
const sdl = @import("sdl").c;
const sdlPanic = @import("sdl").sdlPanic;
const debug = @import("debug.zig");
const chip8Logger = @import("logging").chip8;
const sdlLogger = @import("logging").sdl;

// https://chip8.gulrak.net/ ALL QUIRKS DOCS

const FPS = 60;
const INSTR_X_FRAME: u32 = 15;
const MILLISECOND_X_FRAME = (1000 / FPS);

pub const Chip8 = struct {
    running: bool = false,

    opcode: u16 = 0,
    memory: [4096]u8, // 4KB
    PC: u16 = 0x200,
    I: u16 = 0,
    V: [16]u8,

    stack: [16]u16,
    SP: u16 = 0,

    gfx: [64 * 32]u8,

    delayTimer: u8 = 0,
    soundTimer: u8 = 0,

    keys: [16]u8,

    draw: bool,

    renderer: *sdl.SDL_Renderer,

    cycles: i32,
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

// ------------ Core functions ------------

// Init function
pub fn init(rom: []u8, renderer: *sdl.SDL_Renderer) Chip8 {
    var chip8: Chip8 = .{ .memory = undefined, .V = undefined, .stack = undefined, .gfx = undefined, .keys = undefined, .PC = 0x200, .I = 0, .draw = false, .opcode = 0, .delayTimer = 0, .running = false, .soundTimer = 0, .SP = 0, .renderer = renderer, .cycles = 0 };

    @memset(&chip8.memory, 0);
    @memset(&chip8.V, 0);
    @memset(&chip8.stack, 0);
    @memset(&chip8.gfx, 0);
    @memset(&chip8.keys, 0);

    // Load fonts
    @memcpy(chip8.memory[0..FONT.len], &FONT);

    // Load rom
    @memcpy(chip8.memory[0x200 .. 0x200 + rom.len], rom);

    return chip8;
}

pub fn run(chip8: *Chip8) !void {
    chip8.running = true;
    var ins_counter: u32 = 0;

    var breakpoint: i32 = -1;

    while (chip8.running) {
        const startFrameTime: u32 = sdl.SDL_GetTicks();

        handleInput(chip8);

        while (ins_counter < INSTR_X_FRAME) : (ins_counter += 1) { // INSTRUCTION RUNNER
            if (chip8.PC == breakpoint and breakpoint != -1) {
                debug.printChip8State(chip8) catch {};
                chip8Logger.info("Breakpoint reaced: 0x{x:0>4} Press 'n' for get to next instruction \n", .{breakpoint});

                var stdin_buffer: [1024]u8 = undefined;
                var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
                _ = try stdin_reader.interface.takeDelimiterExclusive('\n');
                switch (stdin_buffer[0]) {
                    'n', 'N' => { // if n go to next instruction
                        breakpoint += 2;
                    },
                    else => {
                        // continue normally
                    },
                }
            }

            step(chip8);
            chip8.cycles += 1;
        }

        //Delay
        updateDelay(&ins_counter, chip8);

        // RENDER
        if (chip8.draw) {
            draw(chip8.*);
            chip8.draw = false;
        }

        const frameDuration: u32 = sdl.SDL_GetTicks() - startFrameTime;
        if (frameDuration < MILLISECOND_X_FRAME) {
            sdl.SDL_Delay(MILLISECOND_X_FRAME - frameDuration);
        }
    }

    return;
}

fn updateDelay(ins_counter: *u32, chip8: *Chip8) void {
    const count: u32 = ins_counter.*;
    if (count >= INSTR_X_FRAME) {
        if (chip8.delayTimer > 0) chip8.delayTimer -= 1;
        if (chip8.soundTimer > 0) chip8.soundTimer -= 1;
        ins_counter.* = 0;
    }
}

fn handleInput(chip8: *Chip8) void {
    var e: sdl.SDL_Event = undefined;
    while (sdl.SDL_PollEvent(&e) != 0) {
        if (e.type == sdl.SDL_QUIT) {
            chip8.running = false;
            break;
        }
        if (e.type == sdl.SDL_KEYDOWN or e.type == sdl.SDL_KEYUP) {
            const pressed: u8 = if (e.type == sdl.SDL_KEYDOWN) 1 else 0;
            switch (e.key.keysym.sym) {
                sdl.SDLK_1 => chip8.keys[0x1] = pressed,
                sdl.SDLK_2 => chip8.keys[0x2] = pressed,
                sdl.SDLK_3 => chip8.keys[0x3] = pressed,
                sdl.SDLK_4 => chip8.keys[0xC] = pressed,

                sdl.SDLK_q => chip8.keys[0x4] = pressed,
                sdl.SDLK_w => chip8.keys[0x5] = pressed,
                sdl.SDLK_e => chip8.keys[0x6] = pressed,
                sdl.SDLK_r => chip8.keys[0xD] = pressed,

                sdl.SDLK_a => chip8.keys[0x7] = pressed,
                sdl.SDLK_s => chip8.keys[0x8] = pressed,
                sdl.SDLK_d => chip8.keys[0x9] = pressed,
                sdl.SDLK_f => chip8.keys[0xE] = pressed,

                sdl.SDLK_z => chip8.keys[0xA] = pressed,
                sdl.SDLK_x => chip8.keys[0x0] = pressed,
                sdl.SDLK_c => chip8.keys[0xB] = pressed,
                sdl.SDLK_v => chip8.keys[0xF] = pressed,
                else => {},
            }
        }
    }
}

fn fetch(chip8: Chip8) u16 {
    const high: u16 = @intCast(chip8.memory[@intCast(chip8.PC)]);
    const low: u16 = @intCast(chip8.memory[@intCast(chip8.PC + 1)]);
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

fn step(chip8: *Chip8) void {
    chip8.opcode = fetch(chip8.*);

    debug.printChip8State(chip8) catch {
        chip8Logger.warn("Some error logging current state", .{});
    };

    execute(chip8, chip8.opcode);
    chip8.PC += 2;
}

fn execute(chip8: *Chip8, opcode: u16) void {
    switch (opcode & 0xF000) {
        0x0000 => { // 0x0NNN family - Flow / SYS family
            switch (opcode & 0xF0FF) {
                0x00E0 => { // 0x00E0 - CLS: Clear the display
                    @memset(&chip8.gfx, 0);
                    chip8.draw = true;
                },
                0x00EE => { // 0x00EE - RET: Return from subroutine
                    chip8.SP -= 1;
                    chip8.PC = chip8.stack[chip8.SP];
                    chip8.PC -= 2; // Compense the +2 in the calling function
                },
                0x0000 => { // 0x0NNN - SYS addr: Jump to a machine code routine at NNN (ignored on modern interpreters)
                    const addr = opcode & 0x0FFF;
                    chip8.PC = addr;
                    chip8.PC -= 2; // Compense the +2 in the calling function
                },
                else => {
                    unknowOpcode(chip8);
                },
            }
        },
        0x1000 => { // 0x1NNN - JP addr: Jump to address NNN
            chip8.PC = chip8.opcode & 0x0FFF;
            chip8.PC -= 2; // Compense the +2 in the calling function
        },
        0x2000 => { // 0x2NNN - CALL addr: Call subroutine at NNN
            const return_addr: u16 = chip8.PC + 2; // Save current address + 2
            const target: u16 = chip8.opcode & 0x0FFF; // Destination address

            chip8.stack[chip8.SP] = return_addr; // Save in the current stack position the return address
            chip8.SP += 1; // Increment the stack pointer

            chip8.PC = target; // Set the address

            chip8.PC -= 2; // Compense the +2 in the calling function
        },
        0x3000 => { // 0x3XNN - SE Vx, byte: Skip next instruction if Vx == NN
            const index_reg = (chip8.opcode & 0x0F00) >> 8;
            const constant_8 = (chip8.opcode & 0x00FF);

            if (chip8.V[index_reg] == constant_8) {
                chip8.PC += 2;
            }
        },
        0x4000 => { // 0x4XNN - SNE Vx, byte: Skip next instruction if Vx != NN
            const index_reg = (chip8.opcode & 0x0F00) >> 8;
            const constant_8 = (chip8.opcode & 0x00FF);

            if (chip8.V[index_reg] != constant_8) {
                chip8.PC += 2;
            }
        },
        0x5000 => { // 0x5XY0 - SE Vx, Vy: Skip next instruction if Vx == Vy
            const x = (chip8.opcode & 0x0F00) >> 8;
            const y = (chip8.opcode & 0x00F0) >> 4;

            if (chip8.V[x] == chip8.V[y]) {
                chip8.PC += 2;
            }
        },
        0x6000 => { // 0x6XNN - LD Vx, byte: Set Vx = NN
            const x = (chip8.opcode & 0x0F00) >> 8;
            const value: u8 = @intCast(chip8.opcode & 0x00FF);
            chip8.V[x] = value;
        },
        0x7000 => { // 0x7XNN - ADD Vx, byte: Set Vx = Vx + NN
            const x = (chip8.opcode & 0x0F00) >> 8;
            const value: u8 = @intCast(chip8.opcode & 0x00FF);
            chip8.V[x], chip8.V[0xF] = @addWithOverflow(chip8.V[x], value);
        },
        0x8000 => { // 0x8XY_ - Arithmetic and logic operations between Vx and Vy
            switch (opcode & 0xF00F) {
                0x8000 => { // 0x8XY0 - LD Vx, Vy: Set Vx = Vy
                    const x = (chip8.opcode & 0x0F00) >> 8;
                    const y = (chip8.opcode & 0x00F0) >> 4;
                    chip8.V[x] = chip8.V[y];
                },
                0x8001 => { // 0x8XY1 - OR Vx, Vy: Set Vx = Vx OR Vy
                    const x = (chip8.opcode & 0x0F00) >> 8;
                    const y = (chip8.opcode & 0x00F0) >> 4;
                    chip8.V[x] |= chip8.V[y];
                    chip8.V[0xF] = 0; // quirks 5
                },
                0x8002 => { // 0x8XY2 - AND Vx, Vy: Set Vx = Vx AND Vy
                    const x = (chip8.opcode & 0x0F00) >> 8;
                    const y = (chip8.opcode & 0x00F0) >> 4;
                    chip8.V[x] &= chip8.V[y];
                    chip8.V[0xF] = 0; // quirks 5
                },
                0x8003 => { // 0x8XY3 - XOR Vx, Vy: Set Vx = Vx XOR Vy
                    const x = (chip8.opcode & 0x0F00) >> 8;
                    const y = (chip8.opcode & 0x00F0) >> 4;
                    chip8.V[x] ^= chip8.V[y];
                    chip8.V[0xF] = 0; // quirks 5
                },
                0x8004 => { // 0x8XY4 - ADD Vx, Vy: Set Vx = Vx + Vy, set VF = carry
                    const x = (chip8.opcode & 0x0F00) >> 8;
                    const y = (chip8.opcode & 0x00F0) >> 4;

                    const X: u16 = @intCast(chip8.V[x]);
                    const Y: u16 = @intCast(chip8.V[y]);
                    const carry: u8 = if (X + Y > 0xFF) 1 else 0;
                    chip8.V[x], _ = @addWithOverflow(chip8.V[x], chip8.V[y]);

                    chip8.V[0xF] = carry;
                },
                0x8005 => { // 0x8XY5 - SUB Vx, Vy: Set Vx = Vx - Vy, set VF = NOT borrow
                    const x = (chip8.opcode & 0x0F00) >> 8;
                    const y = (chip8.opcode & 0x00F0) >> 4;

                    var carry: u8 = 0;
                    if (chip8.V[x] >= chip8.V[y]) {
                        carry = 1;
                    }
                    chip8.V[x], _ = @subWithOverflow(chip8.V[x], chip8.V[y]);
                    chip8.V[0xF] = carry;
                },
                0x8006 => { // 0x8XY6 - SHR Vx {, Vy}: Set Vx = Vx >> 1, VF = least significant bit prior to shift
                    const x = (chip8.opcode & 0x0F00) >> 8;

                    const carry: u8 = @intCast(chip8.V[x] & 1);
                    chip8.V[x] >>= 1;
                    chip8.V[0xF] = carry;
                },
                0x8007 => { // 0x8XY7 - SUBN Vx, Vy: Set Vx = Vy - Vx, set VF = NOT borrow
                    const x = (chip8.opcode & 0x0F00) >> 8;
                    const y = (chip8.opcode & 0x00F0) >> 4;

                    var carry: u8 = 0;
                    if (chip8.V[y] >= chip8.V[x]) {
                        carry = 1;
                    }
                    chip8.V[x], _ = @subWithOverflow(chip8.V[y], chip8.V[x]);
                    chip8.V[0xF] = carry;
                },
                0x800E => { // 0x8XYE - SHL Vx {, Vy}: Set Vx = Vx << 1, VF = most significant bit prior to shift
                    const x = (chip8.opcode & 0x0F00) >> 8;

                    var carry: u8 = 0;
                    chip8.V[x], carry = @shlWithOverflow(chip8.V[x], 1);
                    chip8.V[0xF] = carry;
                },
                else => {
                    unknowOpcode(chip8);
                },
            }
        },
        0x9000 => { // 0x9XY0 - SNE Vx, Vy: Skip next instruction if Vx != Vy
            const x = (chip8.opcode & 0x0F00) >> 8;
            const y = (chip8.opcode & 0x00F0) >> 4;

            if (chip8.V[x] != chip8.V[y]) {
                chip8.PC += 2;
            }
        },
        0xA000 => { // 0xANNN - LD I, addr: Set I = NNN
            const address = chip8.opcode & 0x0FFF;
            chip8.I = address;
        },
        0xB000 => { // 0xBNNN Set the PC with V0 + NNN
            const nnn = chip8.opcode & 0x0FFF;
            chip8.PC = chip8.V[0] + nnn;
        },
        0xC000 => { // 0xCXNN Random number wrapped with nn
            const nn: u8 = @intCast(chip8.opcode & 0x00FF);
            const x = (chip8.opcode & 0x0F00) >> 8;
            chip8.V[x] = std.crypto.random.int(u8) & nn;
        },
        0xD000 => { // 0xDXYN - DRW Vx, Vy, nibble: Draw sprite at (Vx, Vy) with height N
            const witdh = 8;
            const height = chip8.opcode & 0x000F;

            const x = chip8.V[(chip8.opcode & 0x0F00) >> 8] & 0x3F; // And with 63 for wrapping
            const y = chip8.V[(chip8.opcode & 0x00F0) >> 4] & 0x1F; // And with 31 for wrapping

            chip8.V[0xF] = 0;

            var yline: u16 = 0;
            while (yline < height) : (yline += 1) {
                const pixels = chip8.memory[chip8.I + yline];
                var xline: u16 = 0;

                while (xline < witdh) : (xline += 1) {
                    const px = x + xline;
                    const py = y + yline;
                    if ((pixels >> @intCast(7 - xline)) & 1 != 0) {
                        if (px < 64 and py < 32) {
                            const index = px + ((py) * 64);
                            if (chip8.gfx[index] == 1)
                                chip8.V[0xF] = 1;
                            chip8.gfx[index] ^= 1; // Edit pixel
                        }
                    }
                }
            }

            chip8.draw = true;
        },
        0xE000 => { // 0xEX__ - Key operations
            switch (opcode & 0xF0FF) {
                0xE09E => { // 0xEX9E - SKP Vx: Skip next instruction if key with the value of Vx is pressed
                    const x = (chip8.opcode & 0x0F00) >> 8;
                    if (chip8.keys[chip8.V[x]] == 1) {
                        chip8.PC += 2;
                    }
                },
                0xE0A1 => { // 0xEXA1 - SKNP Vx: Skip next instruction if key with the value of Vx is not pressed
                    const x = (chip8.opcode & 0x0F00) >> 8;
                    if (chip8.keys[chip8.V[x]] != 1) {
                        chip8.PC += 2;
                    }
                },
                else => {
                    unknowOpcode(chip8);
                },
            }
        },
        0xF000 => { // 0xFX__ - Miscellaneous timers, memory, and I/V registers
            switch (opcode & 0xF0FF) {
                0xF007 => { // 0xFX07 - LD Vx, DT: Set Vx = delay timer value
                    const x = (chip8.opcode & 0x0F00) >> 8;
                    chip8.V[x] = chip8.delayTimer;
                },
                0xF00A => { // 0xFX0A - LD Vx, K: Wait for a key press, store the value of the key in Vx
                    var i: u8 = 0;
                    var founded: bool = false;
                    while (i < 16 and !founded) : (i += 1) {
                        if (chip8.keys[i] == 1) {
                            chip8.V[0x0] = i;
                            founded = true;
                        }
                    }
                    if (!founded) {
                        chip8.PC -= 2;
                    }
                },
                0xF015 => { // 0xFX15 - LD DT, Vx: Set delay timer = Vx
                    const x = (chip8.opcode & 0x0F00) >> 8;
                    chip8.delayTimer = chip8.V[x];
                },
                0xF018 => { // 0xFX18 Set delay timer
                    const x = (chip8.opcode & 0x0F00) >> 8;
                    chip8.soundTimer = chip8.V[x];
                }, // 0xFX18 - LD ST, Vx: Set sound timer = Vx
                0xF01E => { // 0xFX1E - ADD I, Vx: Set I = I + Vx
                    const reg = (chip8.opcode & 0x0F00) >> 8;
                    const old_i: u16 = chip8.I;
                    const value: u16 = chip8.V[reg];

                    chip8.I = old_i + value;
                },
                0xF029 => { // 0xFX29 - LD F, Vx: Set I = location of letter for digit Vx
                    const x = (chip8.opcode & 0x0F00) >> 8;
                    chip8.I = chip8.V[x] * 5;
                },
                0xF033 => { // 0xFX33 - LD B, Vx: Store BCD representation of Vx in memory at I, I+1, I+2
                    const reg_target = (chip8.opcode & 0x0F00) >> 8;
                    const value_bcd = chip8.V[reg_target];

                    const ones: u8 = @intCast(value_bcd % 10);
                    const tens: u8 = @intCast((value_bcd / 10) % 10);
                    const hundreds: u8 = @intCast((value_bcd / 100) % 10);

                    chip8.memory[chip8.I + 2] = ones;
                    chip8.memory[chip8.I + 1] = tens;
                    chip8.memory[chip8.I] = hundreds;
                },
                0xF055 => { // 0xFX55 - LD [I], Vx: Store V0..Vx in memory starting at I
                    const x = (chip8.opcode & 0x0F00) >> 8;
                    var i: usize = 0;

                    while (i <= x) : (i += 1) {
                        chip8.memory[chip8.I + i] = @intCast(chip8.V[i]);
                    }
                    chip8.I += (x + 1);
                },
                0xF065 => { // 0xFX65 - LD Vx, [I]: Read V0..Vx from memory starting at I
                    const x = (chip8.opcode & 0x0F00) >> 8;
                    var i: usize = 0;

                    while (i <= x) : (i += 1) {
                        chip8.V[i] = chip8.memory[chip8.I + i];
                    }

                    chip8.I += (x + 1);
                },
                else => {
                    unknowOpcode(chip8);
                },
            }
        },
        else => {
            unknowOpcode(chip8);
        },
    }
}

fn unknowOpcode(chip8: *Chip8) void {
    chip8Logger.err("Unknown opcode: 0x{x:0>4}\n", .{chip8.opcode});
    chip8.running = false;
}
