const std = @import("std");
const os = std.os;
const linux = os.linux;
const fs = std.fs;

var stdout = std.io.getStdOut().writer();
var stdin = std.io.getStdIn().reader();

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

    _ = linux.tcsetattr(tty_fd, linux.TCSA.NOW, &new_settings);

    try stdout.writeAll("\x1B[?25l"); // Hide the cursor.
    try stdout.writeAll("\x1B[s"); // Save cursor position.
    try stdout.writeAll("\x1B[?47h"); // Save screen.
    try stdout.writeAll("\x1B[?1049h"); // Enable alternative buffer.

    try moveCursor(stdout, 0, 0);

    while (true) {
        var input_buffer: [1]u8 = undefined;
        _ = try tty_file.read(&input_buffer);

        if (input_buffer[0] == 'q') {
            _ = linux.tcsetattr(tty_fd, linux.TCSA.NOW, &old_settings);
            try stdout.writeAll("\x1B[?1049l"); // Disable alternative buffer.
            try stdout.writeAll("\x1B[?47l"); // Restore screen.
            try stdout.writeAll("\x1B[u"); // Restore cursor position.
            return;
        }

        try stdout.print("typed: ({c})\r\n", .{input_buffer[0]});
    }
}

fn moveCursor(writer: anytype, row: usize, col: usize) !void {
    _ = try writer.print("\x1B[{};{}H", .{ row + 1, col + 1 });
}
