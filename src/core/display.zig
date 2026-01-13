const std = @import("std");
const fs = std.fs;

const Buffer = struct {
    var currentLine: u32 = 0;
    var currentChar: u32 = 0;
    var lines: []Line = undefined;

    pub fn getCurrentLine() !Line {
        if (currentLine > lines.len) {
            return error.OUT_OF_BOUNDS;
        }
        return lines[currentLine];
    }

    pub fn getCurrentChar() !u8 {
        return try getCurrentLine()[currentChar];
    }
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
