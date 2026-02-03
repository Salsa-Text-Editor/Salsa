const std = @import("std");
const posix = std.posix;
const fs = std.fs;

pub fn setupTerminal(tty_fd: posix.system.fd_t) !posix.termios {
    const old_settings: posix.termios = try posix.tcgetattr(tty_fd);
    var new_settings: posix.termios = old_settings;
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
    new_settings.cc[@intFromEnum(posix.V.MIN)] = 0;

    try posix.tcsetattr(tty_fd, posix.TCSA.FLUSH, new_settings);
    return old_settings;
}

pub fn resetTerminal(tty_fd: posix.system.fd_t, old_settings: posix.termios) !void {
    try posix.tcsetattr(tty_fd, posix.TCSA.FLUSH, old_settings);
}

pub fn moveCursor(writer: fs.File.Writer, row: usize, col: usize) !void {
    try writer.print("\x1B[{};{}H", .{ row, col });
}

pub fn hideCursor(writer: fs.File.Writer) !void {
    try writer.writeAll("\x1B[?25l");
}

pub fn restoreCursor(writer: fs.File.Writer) !void {
    try writer.writeAll("\x1B[u");
}

pub fn saveCursor(writer: fs.File.Writer) !void {
    try writer.writeAll("\x1B[s");
}

pub fn alternateBuffer(writer: fs.File.Writer) !void {
    try writer.writeAll("\x1B[?1049h");
}

pub fn originalBuffer(writer: fs.File.Writer) !void {
    try writer.writeAll("\x1B[?1049l");
}

pub fn restoreScreen(writer: fs.File.Writer) !void {
    try writer.writeAll("\x1B[?47l");
}

pub fn saveScreen(writer: fs.File.Writer) !void {
    try writer.writeAll("\x1B[?47h");
}

pub fn clearBuffer(writer: fs.File.Writer) !void {
    try writer.writeAll("\x1B[3J");
}
