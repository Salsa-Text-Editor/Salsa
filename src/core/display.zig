const std = @import("std");
const fs = std.fs;
const mem = std.mem;

const core_terminal = @import("terminal.zig");

pub const Buffer = struct {
    lines: []Line = undefined,
    allocator: mem.Allocator = undefined,
    columns: usize = undefined,
    rows: usize = undefined,

    const Self = @This();

    pub fn init(allocator: mem.Allocator, rows: usize, columns: usize) !Self {
        const lines = try allocator.alloc(Line, rows);
        for (lines) |*line| {
            line.* = try Line.init(allocator, columns);
        }
        return Buffer{ .allocator = allocator, .lines = lines, .rows = rows, .columns = columns };
    }

    pub fn deinit(self: Self) void {
        for (self.lines) |line| {
            line.deinit();
        }
        self.allocator.free(self.lines);
    }

    pub fn setChar(self: Self, row: usize, column: usize, char: u8) void {
        self.lines[row - 1].chars[column] = char;
    }

    pub fn getChar(self: Self, row: usize, column: usize) u8 {
        return self.lines[row - 1].chars[column];
    }
};

const Line = struct {
    chars: []u8 = undefined,
    allocator: mem.Allocator = undefined,
    length: usize = undefined,

    const Self = @This();

    pub fn init(allocator: mem.Allocator, length: usize) !Self {
        const line: []u8 = try allocator.alloc(u8, length);
        return Self{ .chars = line, .allocator = allocator, .length = length };
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.chars);
    }

    pub fn setChar(self: Self, position: usize, char: u8) void {
        self.chars[position - 1] = char;
    }

    pub fn getChar(self: Self, position: usize) u8 {
        return self.chars[position - 1];
    }

    pub fn getLength(self: Self) usize {
        return self.length;
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
