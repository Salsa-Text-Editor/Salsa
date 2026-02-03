const std = @import("std");
const posix = std.posix;
const io = std.io;
const fs = std.fs;
const mem = std.mem;
const heap = std.heap;

const cterminal = @import("core/terminal.zig");
const cdisplay = @import("core/display.zig");
const csalsa = @import("core/salsa.zig");
const cinput = @import("core/input.zig");

pub fn main() !void {
    const stdout = io.getStdOut().writer();
    const stdin = io.getStdIn().reader();
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    defer {
        const status = gpa.deinit();
        if (status == .leak) {
            @panic("memory leak detected!!!");
        }
    }

    // work on display manager
    // work on plugin manager

    const tty_file: fs.File = try fs.openFileAbsolute("/dev/tty", .{});
    defer tty_file.close();
    const tty_fd: posix.system.fd_t = tty_file.handle;

    const old_settings: posix.termios = try cterminal.setupTerminal(tty_fd);

    try csalsa.initSalsa(stdout);

    var win_size = posix.winsize{
        .row = 0,
        .col = 0,
        .xpixel = 0,
        .ypixel = 0,
    };

    const err = posix.system.ioctl(tty_fd, posix.T.IOCGWINSZ, @intFromPtr(&win_size));
    if (posix.errno(err) == .SUCCESS) {}

    var main_buffer = try cdisplay.Buffer.init(allocator, win_size.row - 1, win_size.col, 'e');
    defer main_buffer.deinit();
    while (true) {
        const input = try cinput.pollEvents(stdin, allocator);
        defer allocator.free(input);
        if (input.len > 0) {
            try main_buffer.setChar(1, 1, input[0]);
            try cdisplay.renderBuffer(stdout, main_buffer);
        }
        if (mem.eql(u8, input, "q")) {
            try csalsa.deinitSalsa(stdout, tty_fd, old_settings);
            return;
        }
    }
}
