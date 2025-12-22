const std = @import("std");
const os = std.os;
const linux = os.linux;
const io = std.io;
const fs = std.fs;
const mem = std.mem;

var stdout = io.getStdOut().writer();
var stdin = io.getStdIn().reader();

pub fn main() !void {
    const tty_file = try fs.openFileAbsolute("/dev/tty", .{});
    defer tty_file.close();
    const tty_fd = tty_file.handle;

    var old_settings: linux.termios = undefined;
    _ = linux.tcgetattr(tty_fd, &old_settings);

    var new_settings: linux.termios = old_settings;
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

    new_settings.cc[@intFromEnum(linux.V.TIME)] = 0;
    new_settings.cc[@intFromEnum(linux.V.MIN)] = 1;

    _ = linux.tcsetattr(tty_fd, linux.TCSA.FLUSH, &new_settings);

    try stdout.writeAll("\x1B[?25l"); // Hide the cursor.
    try stdout.writeAll("\x1B[s"); // Save cursor position.
    try stdout.writeAll("\x1B[?47h"); // Save screen.
    try stdout.writeAll("\x1B[?1049h"); // Enable alternative buffer.

    try moveCursor(stdout, 0, 0);

    while (true) {
        var input_buffer: [1]u8 = undefined;
        _ = try tty_file.read(&input_buffer);

        switch (input_buffer[0]) {
            'q' => {
                _ = linux.tcsetattr(tty_fd, linux.TCSA.FLUSH, &old_settings);
                try stdout.writeAll("\x1B[?1049l"); // Disable alternative buffer.
                try stdout.writeAll("\x1B[?47l"); // Restore screen.
                try stdout.writeAll("\x1B[u"); // Restore cursor position.
                return;
            },
            '\x1B' => {
                new_settings.cc[@intFromEnum(linux.V.TIME)] = 1;
                new_settings.cc[@intFromEnum(linux.V.MIN)] = 0;
                _ = linux.tcsetattr(tty_fd, linux.TCSA.NOW, &new_settings);

                var escape_buffer: [8]u8 = undefined;
                const escape_read = try tty_file.read(&escape_buffer);

                new_settings.cc[@intFromEnum(linux.V.TIME)] = 0;
                new_settings.cc[@intFromEnum(linux.V.MIN)] = 1;
                _ = linux.tcsetattr(tty_fd, linux.TCSA.NOW, &new_settings);

                if (escape_read == 0) {
                    try stdout.print("typed: (escape)\r\n", .{});
                } else if (mem.eql(u8, escape_buffer[0..escape_read], "[A")) {
                    try stdout.print("typed: (up arrow)\r\n", .{});
                } else if (mem.eql(u8, escape_buffer[0..escape_read], "[B")) {
                    try stdout.print("typed: (down arrow)\r\n", .{});
                } else if (mem.eql(u8, escape_buffer[0..escape_read], "[C")) {
                    try stdout.print("typed: (right arrow)\r\n", .{});
                } else if (mem.eql(u8, escape_buffer[0..escape_read], "[D")) {
                    try stdout.print("typed: (left arrow)\r\n", .{});
                } else if (mem.eql(u8, escape_buffer[0..escape_read], "a")) {
                    try stdout.print("typed: (alt-a)\r\n", .{});
                } else {
                    try stdout.print("typed: (unkown escape sequence)\r\n", .{});
                }
            },
            else => {
                try stdout.print("typed: ({c})\r\n", .{input_buffer[0]});
            },
        }
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
