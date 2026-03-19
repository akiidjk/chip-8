const std = @import("std");

pub const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

pub fn sdlPanic() noreturn {
    const str = @as(?[*:0]const u8, c.SDL_GetError()) orelse "unknown error";
    @panic(std.mem.sliceTo(str, 0));
}
