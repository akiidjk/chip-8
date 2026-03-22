const std = @import("std");
const chip8 = @import("chip_8");
const sdl = @import("sdl").c;
const sdlPanic = @import("sdl").sdlPanic;
const chip8Logger = @import("logging").chip8;
const sdlLogger = @import("logging").sdl;
const log = @import("logging").log;
const logging = @import("logging");
const posix = std.posix;

const AMPLITUDE = 3000;
const FREQUENCY = 440;

pub const std_options: std.Options = .{ .logFn = logging.formatFn, .log_level = logging.default_level, .log_scope_levels = &[_]std.log.ScopeLevel{
    .{ .scope = .sdl, .level = .debug },
    .{ .scope = .chip8, .level = .debug },
} };

fn handleCtrlC(signum: i32) callconv(.c) void {
    std.process.exit(0);
    std.debug.print("\n[!] Caught Ctrl+C (signal {}), Shutting down...\n", .{signum});
}

fn audio_callback(userdata: ?*anyopaque, stream: [*c]u8, len: c_int) callconv(.c) void {
    const chip: *chip8.Chip8 = @ptrCast(@alignCast(userdata));
    var buffer: [*c]i16 = @ptrCast(@alignCast(stream));
    const length: i32 = @divTrunc(len, 2);

    var sample_index: u32 = 0;

    var i: usize = 0;
    while (i < length) : (i += 1) {
        if (chip.soundTimer == 0) {
            buffer[i] = 0;
            sample_index = 0;
        } else {
            const half_period: i32 = 44100 / (FREQUENCY * 2);
            sample_index += 1;
            buffer[i] = if ((@divTrunc(sample_index, half_period) % 2) == 1) AMPLITUDE else -AMPLITUDE;
        }
    }
    return;
}

fn setupSigint() void {
    var sa = posix.Sigaction{
        .handler = .{ .handler = handleCtrlC },
        .mask = posix.sigemptyset(),
        .flags = 0,
    };
    _ = posix.sigaction(posix.SIG.INT, &sa, null);
}

fn initSDL() struct { *sdl.SDL_Window, *sdl.SDL_Renderer } {
    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_EVENTS | sdl.SDL_INIT_AUDIO) < 0)
        sdlPanic();

    const window = sdl.SDL_CreateWindow(
        "chip-8",
        sdl.SDL_WINDOWPOS_CENTERED,
        sdl.SDL_WINDOWPOS_CENTERED,
        1740, // 720
        980, // 360
        sdl.SDL_WINDOW_SHOWN,
    ) orelse sdlPanic();

    const renderer = sdl.SDL_CreateRenderer(window, -1, sdl.SDL_RENDERER_ACCELERATED) orelse sdlPanic();

    _ = sdl.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xFF);
    sdl.SDL_RenderPresent(renderer);
    _ = sdl.SDL_RenderClear(renderer);

    return .{ window, renderer };
}

fn audioInit(chip: *chip8.Chip8) void {
    var want: sdl.SDL_AudioSpec = undefined;
    var have: sdl.SDL_AudioSpec = undefined;

    want.freq = 44100; // Standard CD Quality frequency
    want.format = sdl.AUDIO_S16SYS; // 16-bit signed samples
    want.channels = 1; // Mono
    want.samples = 4096; // Buffer size
    want.userdata = chip; // Pass chip8 so that the callback can check sound_timer
    want.callback = audio_callback; // Function that will generate the sound wave

    if (sdl.SDL_OpenAudio(&want, &have) < 0) {
        sdlLogger.err("Failed to open audio: {s}", .{sdl.SDL_GetError()});
    }
    sdl.SDL_PauseAudio(0);
}

fn closeSDL(window: *sdl.SDL_Window, renderer: *sdl.SDL_Renderer) void {
    defer sdl.SDL_Quit();
    defer _ = sdl.SDL_DestroyRenderer(renderer);
    defer _ = sdl.SDL_DestroyWindow(window);
}

fn getRom(allocator: std.mem.Allocator, romPath: [*:0]u8) ![]u8 {
    const romFile = try std.fs.cwd().openFileZ(romPath, .{ .mode = .read_only });
    defer romFile.close();

    const romContent = try allocator.alloc(u8, 4096);

    var total: usize = 0;
    while (total < romContent.len) {
        const n = try romFile.read(romContent[total..]);
        if (n == 0) break;
        total += n;
    }
    const romSlice = romContent[0..total];

    return romSlice;
}

fn printHelp() void {
    log.info("Usage: ./chip8 <rom> <address for breakpoint (optional)>", .{});
}

fn argsHandling(allocator: std.mem.Allocator, argv: [][*:0]u8) !struct { romSlice: []u8, breakpoint: i32 } {
    if (argv.len < 2) {
        log.err("You need to insert at least the rom to execute\n", .{});
        printHelp();
        std.process.exit(1);
    }

    for (argv) |arg| {
        if (std.mem.eql(u8, std.mem.span(arg), "--help")) {
            printHelp();
            std.process.exit(0);
        }
    }

    const romPath = argv[1];
    log.info("Rom selected {s}\n", .{romPath});
    const romSlice = getRom(allocator, romPath) catch {
        log.err("Failed to read rom\n", .{});
        std.process.exit(1);
    };

    var breakpoint: i32 = -1;
    if (argv.len > 2) {
        const bp_str = argv[2];
        breakpoint = std.fmt.parseInt(i32, std.mem.span(bp_str), 16) catch |e| {
            log.err("Invalid breakpoint: {s} with error {} remember to use base 16 without 0x\n", .{ bp_str, e });
            std.process.exit(1);
        };
    }

    return .{ .romSlice = romSlice, .breakpoint = breakpoint };
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const result = try argsHandling(allocator, std.os.argv);
    defer allocator.free(result.romSlice);

    const window, const renderer = initSDL();
    defer closeSDL(window, renderer);

    setupSigint();
    var chip8Istance = chip8.init(
        result.romSlice,
        renderer,
    );
    chip8Istance.breakpoint = result.breakpoint;

    audioInit(&chip8Istance);

    try chip8.run(&chip8Istance);
}
