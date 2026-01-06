const std = @import("std");
const io = std.io;
const mem = std.mem;

fn getNextChar(reader: anytype) !u8 {
    return reader.readByte() catch |err| blk: {
        if (err == error.EndOfStream) {
            break :blk '\x00';
        }
        return err;
    };
}

pub fn pollEvents(reader: anytype, allocator: mem.Allocator) ![]u8 {
    var list: std.ArrayList(u8) = .init(allocator);
    errdefer list.deinit();

    var ch: u8 = try getNextChar(reader);

    while (ch != '\x00') {
        try list.append(ch);
        ch = try getNextChar(reader);
    }

    return list.toOwnedSlice();
}
