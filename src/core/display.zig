const std = @import("std");
const fs = std.fs;
const mem = std.mem;

pub const Buffer = struct {
    lines: []Line = undefined,
    allocator: mem.Allocator = undefined,

    const Self = @This();

    pub fn init(allocator: mem.Allocator, rows: u16, columns: u16) !Self {
        const lines = try allocator.alloc(Line, rows);
        for (lines) |line| {
            line.init(allocator, columns);
        }
        return Buffer{ .allocator = allocator, .lines = lines };
    }

    pub fn deinit(self: Self) void {
        for (self.lines) |line| {
            line.deinit();
        }
        self.allocator.free(self.lines);
    }
};

const Line = struct {
    chars: []u16 = undefined,
    allocator: mem.Allocator = undefined,

    const Self = @This();

    pub fn init(allocator: mem.Allocator, length: u16) !Self {
        const line: []u16 = try allocator.alloc(u16, length);
        return Self{ .chars = line, .allocator = allocator };
    }
    pub fn deinit(self: Self) !void {
        self.allocator.free(self.chars);
    }
};

pub fn renderBuffer(writer: fs.File.Writer, buffer: Buffer) !void {
    for (try buffer.getCurrentLine(), 0..) |line, index| {
        try writer.writeAll(index);
        try writer.writeAll(line);
    }
}
