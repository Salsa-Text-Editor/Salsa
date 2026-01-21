const std = @import("std");
const fs = std.fs;
const mem = std.mem;

const Buffer = struct {
    lines: []Line = undefined,
    allocator: mem.Allocator = undefined,

    pub fn init(allocator: mem.Allocator, rows: u16, columns: u16) !Buffer {
        return Buffer{ .allocator = allocator, .lines = allocator.alloc(u8, rows) };
    }

    pub fn deinit() void {}
};

const Line = struct {
    var chars = []u8;
};

pub fn renderBuffer(writer: fs.File.Writer, buffer: Buffer) !void {
    for (try buffer.getCurrentLine(), 0..) |line, index| {
        try writer.writeAll(index);
        try writer.writeAll(line);
    }
}
