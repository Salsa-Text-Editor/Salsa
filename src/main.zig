const std = @import("std");
const builtin = @import("builtin");
const os = std.os;
const posix = std.posix;
const io = std.io;
const fs = std.fs;
const mem = std.mem;
const heap = std.heap;

const core_terminal = @import("core//terminal.zig");
const core_salsa = @import("core/salsa.zig");
const core_input = @import("core/input.zig");

pub fn main() !void {
    const stdout = io.getStdOut().writer();
    const stdin = io.getStdIn().reader();
    const allocator: mem.Allocator = heap.page_allocator;

    const tty_file: fs.File = try fs.openFileAbsolute("/dev/tty", .{});
    defer tty_file.close();
    const tty_fd: posix.system.fd_t = tty_file.handle;

    const old_settings: posix.termios = try core_terminal.setupTerminal(tty_fd);

    try core_salsa.initSalsa(stdout);

    while (true) {
        const input = try core_input.pollEvents(stdin, allocator);
        if (!mem.eql(u8, input, "\x00")) {
            try stdout.print("pressed key ({s})\r\n", .{input});
        }
        if (mem.eql(u8, input, "q")) {
            try core_salsa.deinitSalsa(stdout, tty_fd, old_settings);
            return;
        }
    }
}
