const std = @import("std");
const posix = std.posix;
const core_terminal = @import("terminal.zig");

pub fn initSalsa(writer: anytype) !void {
    try core_terminal.hideCursor(writer);
    try core_terminal.saveCursor(writer);
    try core_terminal.saveScreen(writer);
    try core_terminal.alternateBuffer(writer);
    try core_terminal.moveCursor(writer, 0, 0);
}

pub fn deinitSalsa(writer: anytype, tty_fd: posix.system.fd_t, old_settings: posix.termios) !void {
    try core_terminal.resetTerminal(tty_fd, old_settings);
    try core_terminal.originalBuffer(writer);
    try core_terminal.restoreScreen(writer);
    try core_terminal.restoreCursor(writer);
}
