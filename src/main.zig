const std = @import("std");
const chip_8 = @import("chip_8");
const sdl = @import("sdl").c;
const sdlPanic = @import("sdl").sdlPanic;
const posix = std.posix;

pub fn handleCtrlC(signum: i32) callconv(.c) void {
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

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    if (std.os.argv.len < 2) {
        std.debug.print("You need to insert at least the rom to execute\n", .{});
        return;
    }

    const rom = std.os.argv[1];
    std.debug.print("Rom selected {s}\n", .{rom});

    const romFile = try std.fs.cwd().openFileZ(rom, .{ .mode = .read_only });
    defer romFile.close();

    const romContent = try allocator.alloc(u8, 4096);
    defer allocator.free(romContent);

    var total: usize = 0;
    while (total < romContent.len) {
        const n = try romFile.read(romContent[total..]);
        if (n == 0) break;
        total += n;
    }
    const romSlice = romContent[0..total];

    if (sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_EVENTS | sdl.SDL_INIT_AUDIO) < 0)
        sdlPanic();
    defer sdl.SDL_Quit();

    const window = sdl.SDL_CreateWindow(
        "chip-8",
        sdl.SDL_WINDOWPOS_CENTERED,
        sdl.SDL_WINDOWPOS_CENTERED,
        720,
        360,
        sdl.SDL_WINDOW_SHOWN,
    ) orelse sdlPanic();
    defer _ = sdl.SDL_DestroyWindow(window);

    setupSigint();
    try chip_8.run(window, romSlice);
}
