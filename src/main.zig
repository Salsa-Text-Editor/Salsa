const std = @import("std");
const os = std.os;
const posix = std.posix;
const io = std.io;
const fs = std.fs;
const mem = std.mem;

pub fn main() !void {
    const stdout = io.getStdOut().writer();
    // const stdin = io.getStdIn().reader();

    const tty_file = try fs.openFileAbsolute("/dev/tty", .{});
    defer tty_file.close();
    const tty_fd = tty_file.handle;

    const old_settings = try posix.tcgetattr(tty_fd);

    var new_settings = old_settings;
    new_settings.lflag.ICANON = false;
    new_settings.lflag.ECHO = false;
    new_settings.lflag.ISIG = false;
    new_settings.lflag.IEXTEN = false;

    new_settings.iflag.IXON = false;
    new_settings.iflag.ICRNL = false;
    new_settings.iflag.BRKINT = false;
    new_settings.iflag.INPCK = false;
    new_settings.iflag.ISTRIP = false;

    new_settings.oflag.OPOST = false;

    new_settings.cflag.CSIZE = .CS8;

    new_settings.cc[@intFromEnum(posix.V.TIME)] = 0;
    new_settings.cc[@intFromEnum(posix.V.MIN)] = 1;

    try posix.tcsetattr(tty_fd, posix.TCSA.FLUSH, new_settings);

    try hideCursor(stdout);
    try saveCursor(stdout);
    try saveScreen(stdout);
    try alternateBuffer(stdout);
    try moveCursor(stdout, 0, 0);

    while (true) {
        var input_buffer: [1]u8 = undefined;
        _ = try tty_file.read(&input_buffer);

        switch (input_buffer[0]) {
            'q' => {
                try posix.tcsetattr(tty_fd, posix.TCSA.FLUSH, old_settings);

                try originalBuffer(stdout);
                try restoreScreen(stdout);
                try restoreCursor(stdout);
                return;
            },
            '\x1B' => {
                new_settings.cc[@intFromEnum(posix.V.TIME)] = 1;
                new_settings.cc[@intFromEnum(posix.V.MIN)] = 0;
                try posix.tcsetattr(tty_fd, posix.TCSA.NOW, new_settings);

                var escape_buffer: [8]u8 = undefined;
                const buffer_length = try tty_file.read(&escape_buffer);

                new_settings.cc[@intFromEnum(posix.V.TIME)] = 0;
                new_settings.cc[@intFromEnum(posix.V.MIN)] = 1;
                try posix.tcsetattr(tty_fd, posix.TCSA.NOW, new_settings);

                try handleEscapeSequences(stdout, buffer_length, escape_buffer);
            },
            else => {
                try stdout.print("typed: ({c})\r\n", .{input_buffer[0]});
            },
        }
    }
}

fn handleEscapeSequences(writer: anytype, buffer_length: usize, escape_buffer: [8]u8) !void {
    if (buffer_length == 0) {
        try writer.print("typed: (escape)\r\n", .{});
    } else if (mem.eql(u8, escape_buffer[0..buffer_length], "[A")) {
        try writer.print("typed: (up arrow)\r\n", .{});
    } else if (mem.eql(u8, escape_buffer[0..buffer_length], "[B")) {
        try writer.print("typed: (down arrow)\r\n", .{});
    } else if (mem.eql(u8, escape_buffer[0..buffer_length], "[C")) {
        try writer.print("typed: (right arrow)\r\n", .{});
    } else if (mem.eql(u8, escape_buffer[0..buffer_length], "[D")) {
        try writer.print("typed: (left arrow)\r\n", .{});
    } else if (mem.eql(u8, escape_buffer[0..buffer_length], "a")) {
        try writer.print("typed: (alt-a)\r\n", .{});
    } else {
        try writer.print("typed: (unkown escape sequence)\r\n", .{});
    }
}

fn moveCursor(writer: anytype, row: usize, col: usize) !void {
    try writer.print("\x1B[{};{}H", .{ row + 1, col + 1 });
}

fn hideCursor(writer: anytype) !void {
    try writer.writeAll("\x1B[?25l");
}

fn restoreCursor(writer: anytype) !void {
    try writer.writeAll("\x1B[u");
}

fn saveCursor(writer: anytype) !void {
    try writer.writeAll("\x1B[s");
}

fn alternateBuffer(writer: anytype) !void {
    try writer.writeAll("\x1B[?1049h");
}

fn originalBuffer(writer: anytype) !void {
    try writer.writeAll("\x1B[?1049l");
}

fn restoreScreen(writer: anytype) !void {
    try writer.writeAll("\x1B[?47l");
}

fn saveScreen(writer: anytype) !void {
    try writer.writeAll("\x1B[?47h");
}
