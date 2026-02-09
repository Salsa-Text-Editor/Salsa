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

    // work on display manager (multiple buffers)
    // work on plugin manager

    const tty_file: fs.File = try fs.openFileAbsolute("/dev/tty", .{});
    defer tty_file.close();
    const tty_fd: posix.system.fd_t = tty_file.handle;

    const old_settings: posix.termios = try cterminal.setupTerminal(tty_fd);

    try csalsa.initSalsa(stdout);

    var terminal = try cterminal.TerminalWindow.init(tty_fd);

    var main_buffer = try cdisplay.Buffer.init(allocator, terminal.rows, terminal.columns, 'e');
    defer main_buffer.deinit();
    var input_reader = try cinput.Reader.init(allocator, stdin);
    defer input_reader.deinit();

    const Mode = enum { Normal, Insert };

    var mode: Mode = .Normal;

    while (true) {
        const input = try input_reader.pollInput();
        try terminal.update();
        try main_buffer.resize(terminal.rows, terminal.columns);
        if (input.len > 0) {
            try main_buffer.setChar(1, 1, input[0]);
            try cdisplay.renderBuffer(stdout, main_buffer);
        }
        if (mem.startsWith(u8, input, "i")) {
            mode = .Insert;
        }
        if (mem.startsWith(u8, input, "q")) {
            try csalsa.deinitSalsa(stdout, tty_fd, old_settings);
            return;
        }
    }
}
