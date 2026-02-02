const std = @import("std");
const fs = std.fs;
const mem = std.mem;

const core_terminal = @import("terminal.zig");

pub const Buffer = struct {
    lines: []Line = undefined,
    allocator: mem.Allocator = undefined,
    columns: u16 = undefined,
    rows: u16 = undefined,

    const Self = @This();

    pub fn init(allocator: mem.Allocator, rows: u16, columns: u16) !Self {
        const lines = try allocator.alloc(Line, rows);
        for (lines) |line| {
            line.init(allocator, columns);
        }
        return Buffer{ .allocator = allocator, .lines = lines, .rows = rows, .columns = columns };
    }

    pub fn deinit(self: Self) void {
        for (self.lines) |line| {
            line.deinit();
        }
        self.allocator.free(self.lines);
    }
};

const Line = struct {
    chars: []u8 = undefined,
    allocator: mem.Allocator = undefined,
    length: u16 = undefined,

    const Self = @This();

    pub fn init(allocator: mem.Allocator, length: u16) !Self {
        const line: []u16 = try allocator.alloc(u8, length);
        return Self{ .chars = line, .allocator = allocator };
    }

    pub fn deinit(self: Self) !void {
        self.allocator.free(self.chars);
    }
};

pub fn renderBuffer(writer: fs.File.Writer, buffer: Buffer) !void {
    for (buffer.lines, 0..) |line, iterator| {
        _ = iterator;
        for (line.chars) |char| {
            try core_terminal.clearBuffer(writer);
            try core_terminal.moveCursor(writer, 1, 1);
            try writer.writeByte(char);
        }
    }
}
