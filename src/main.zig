const std = @import("std");
const chip8 = @import("chip_8");
const sdl = @import("sdl").c;
const sdlPanic = @import("sdl").sdlPanic;
const posix = std.posix;

fn handleCtrlC(signum: i32) callconv(.c) void {
    std.process.exit(0);
    std.debug.print("\n[!] Caught Ctrl+C (signal {}), Shutting down...\n", .{signum});
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
        720,
        360,
        sdl.SDL_WINDOW_SHOWN,
    ) orelse sdlPanic();

    const renderer = sdl.SDL_CreateRenderer(window, -1, sdl.SDL_RENDERER_ACCELERATED) orelse sdlPanic();

    _ = sdl.SDL_SetRenderDrawColor(renderer, 0x00, 0x00, 0x00, 0xFF);
    sdl.SDL_RenderPresent(renderer);
    _ = sdl.SDL_RenderClear(renderer);

    return .{ window, renderer };
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

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    if (std.os.argv.len < 2) {
        std.debug.print("You need to insert at least the rom to execute\n", .{});
        return;
    }

    const romPath = std.os.argv[1];
    std.debug.print("Rom selected {s}\n", .{romPath});

    const romSlice = try getRom(allocator, romPath);
    defer allocator.free(romSlice);

    const window, const renderer = initSDL();
    defer closeSDL(window, renderer);

    setupSigint();
    var chip8Istance = chip8.init(
        romSlice,
        renderer,
    );

    try chip8.run(&chip8Istance);
}
