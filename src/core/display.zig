const std = @import("std");
const fs = std.fs;
const mem = std.mem;

const core_terminal = @import("terminal.zig");

pub const Buffer = struct {
    lines: []Line,
    allocator: mem.Allocator,
    columns: u16,
    rows: u16,
    init_char: u8,

    const Self = @This();

    pub fn init(allocator: mem.Allocator, rows: u16, columns: u16, init_char: u8) !Self {
        const lines = try allocator.alloc(Line, rows);
        for (lines) |*line| {
            line.* = try Line.init(allocator, columns, init_char);
        }
        return Self{ .allocator = allocator, .lines = lines, .rows = rows, .columns = columns };
    }

    pub fn resize(self: *Self, rows: u16, columns: u16) !void {
        self.columns = columns;
        self.rows = rows;
        self.*.lines = try self.allocator.realloc(self.lines, rows);
        for (self.lines) |*line| {
            try line.*.resize(columns);
        }
    }

    pub fn deinit(self: Self) void {
        for (self.lines) |line| {
            line.deinit();
        }
        self.allocator.free(self.lines);
    }

    pub fn setChar(self: Self, row: u16, column: u16, char: u8) !void {
        if (row > self.getRows()) {
            return error.OutOfBounds;
        }
        try self.lines[row - 1].setChar(column, char);
    }

    pub fn getChar(self: Self, row: u16, column: u16) !u8 {
        if (row > self.getRows()) {
            return error.OutOfBounds;
        }
        return try self.lines[row - 1].getChar(column);
    }

    pub fn getRows(self: Self) u16 {
        return self.rows;
    }

    pub fn getColumns(self: Self) u16 {
        return self.columns;
    }
};

const Line = struct {
    chars: []u8 = undefined,
    allocator: mem.Allocator = undefined,
    length: u16 = undefined,

    const Self = @This();

    pub fn init(allocator: mem.Allocator, length: u16, init_char: u8) !Self {
        const line: []u8 = try allocator.alloc(u8, length);
        @memset(line, init_char);
        return Self{ .chars = line, .allocator = allocator, .length = length };
    }

    pub fn resize(self: *Self, length: u16) !void {
        self.length = length;
        self.*.chars = try self.allocator.realloc(self.chars, length);
        @memset(self.*.chars, 'E');
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.chars);
    }

    pub fn setChar(self: Self, position: u16, char: u8) !void {
        if (position > self.getLength()) {
            return error.OutOfBounds;
        }
        self.chars[position - 1] = char;
    }

    pub fn getChar(self: Self, position: u16) !u8 {
        if (position > self.getLength()) {
            return error.OutOfBounds;
        }
        return self.chars[position - 1];
    }

    pub fn getLength(self: Self) u16 {
        return self.length;
    }
};

pub fn renderBuffer(writer: fs.File.Writer, buffer: Buffer) !void {
    try core_terminal.clearBuffer(writer);
    try core_terminal.moveCursor(writer, 1, 1);
    for (buffer.lines, 0..) |line, iterator| {
        _ = iterator;
        for (line.chars) |char| {
            try writer.writeByte(char);
        }
        try writer.writeAll("\r\n");
    }
}
