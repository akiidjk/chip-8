const std = @import("std");
const chip_8 = @import("chip_8");
const SDL = @import("sdl");

pub fn main() !void {
    if (std.os.argv.len < 2) {
        std.debug.print("You need to insert at least the rom to execute", .{});
    }
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
    try chip_8.run(romSlice);
}
