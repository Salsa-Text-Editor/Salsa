const std = @import("std");
const io = std.io;
const mem = std.mem;
const fs = std.fs;

pub const Reader = struct {
    allocator: mem.Allocator,
    reader: fs.File.Reader,
    input: std.ArrayList(u8),

    const Self = @This();

    pub fn init(allocator: mem.Allocator, reader: fs.File.Reader) !Self {
        const input = std.ArrayList(u8).init(allocator);
        return Self{ .allocator = allocator, .reader = reader, .input = input };
    }

    pub fn deinit(self: Self) void {
        self.input.deinit();
    }

    fn getNextChar(self: Self) !u8 {
        return self.reader.readByte() catch |err| blk: {
            if (err == error.EndOfStream) {
                break :blk '\x00';
            }
            return err;
        };
    }

    pub fn pollInput(self: *Self) ![]u8 {
        var ch: u8 = try self.getNextChar();

        var counter: u8 = 0;
        while (ch != '\x00') {
            try self.*.input.insert(counter, ch);
            ch = try self.getNextChar();
            counter += 1;
        }

        return self.input.items;
    }
};
