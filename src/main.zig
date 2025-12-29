const std = @import("std");
const builtin = @import("builtin");
const os = std.os;
const posix = std.posix;
const io = std.io;
const fs = std.fs;
const mem = std.mem;

const InputState = enum { Normal, Escape, CSI };

pub fn main() !void {
    const stdout = io.getStdOut().writer();
    const stdin = io.getStdIn().reader();

    var input_state: InputState = .Normal;

    const tty_file: fs.File = try fs.openFileAbsolute("/dev/tty", .{});
    defer tty_file.close();
    const tty_fd: posix.system.fd_t = tty_file.handle;

    const old_settings: posix.termios = try configureTerminal(tty_fd);

    try initSalsa(stdout);

    while (true) {
        const input_char: u8 = stdin.readByte() catch |err| blk: {
            if (err == error.EndOfStream) {
                break :blk '\x00';
            }
            try deinitSalsa(stdout, tty_fd, old_settings);
            return err;
        };

        switch (input_state) {
            .Normal => {
                try handleNormalInputState(stdout, &input_state, input_char);
            },
            .Escape => try handleEscapeInputState(stdout, &input_state, input_char),
            .CSI => try handleCSIInputState(stdout, &input_state, input_char),
        }
        if (input_char == 'q') {
            try deinitSalsa(stdout, tty_fd, old_settings);
            return;
        }
    }
}

fn configureTerminal(tty_fd: posix.system.fd_t) !posix.termios {
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
fn initSalsa(writer: anytype) !void {
    try hideCursor(writer);
    try saveCursor(writer);
    try saveScreen(writer);
    try alternateBuffer(writer);
    try moveCursor(writer, 0, 0);
}

fn resetTerminal(tty_fd: posix.system.fd_t, old_settings: posix.termios) !void {
    try posix.tcsetattr(tty_fd, posix.TCSA.FLUSH, old_settings);
}

fn deinitSalsa(writer: anytype, tty_fd: posix.system.fd_t, old_settings: posix.termios) !void {
    try resetTerminal(tty_fd, old_settings);
    try originalBuffer(writer);
    try restoreScreen(writer);
    try restoreCursor(writer);
}

fn handleNormalInputState(writer: anytype, input_state: *InputState, input_char: u8) !void {
    switch (input_char) {
        '\x1B' => input_state.* = .Escape,
        '\x00' => {},
        else => try writer.print("typed: ({c})\r\n", .{input_char}),
    }
}

fn handleEscapeInputState(writer: anytype, input_state: *InputState, input_char: u8) !void {
    switch (input_char) {
        '[' => input_state.* = .CSI,
        '\x00' => {
            try writer.writeAll("typed: (escape)\r\n");
            input_state.* = .Normal;
        },
        else => {
            try writer.writeAll("unkown escape sequence\r\n");
            input_state.* = .Normal;
        },
    }
}

fn handleCSIInputState(writer: anytype, input_state: *InputState, input_char: u8) !void {
    switch (input_char) {
        'A' => try writer.writeAll("up arrow\r\n"),
        'B' => try writer.writeAll("down arrow\r\n"),
        'C' => try writer.writeAll("right arrow\r\n"),
        'D' => try writer.writeAll("left arrow\r\n"),
        '\x00' => input_state.* = .Normal,
        else => {
            try writer.writeAll("unkown csi character\r\n");
            input_state.* = .Normal;
        },
    }
}

// fn handleEscapeSequences(writer: anytype, buffer_length: usize, escape_buffer: [8]u8) !void {
//     if (buffer_length == 0) {
//         try writer.print("typed: (escape)\r\n", .{});
//     } else if (mem.eql(u8, escape_buffer[0..buffer_length], "[A")) {
//         try writer.print("typed: (up arrow)\r\n", .{});
//     } else if (mem.eql(u8, escape_buffer[0..buffer_length], "[B")) {
//         try writer.print("typed: (down arrow)\r\n", .{});
//     } else if (mem.eql(u8, escape_buffer[0..buffer_length], "[C")) {
//         try writer.print("typed: (right arrow)\r\n", .{});
//     } else if (mem.eql(u8, escape_buffer[0..buffer_length], "[D")) {
//         try writer.print("typed: (left arrow)\r\n", .{});
//     } else if (mem.eql(u8, escape_buffer[0..buffer_length], "a")) {
//         try writer.print("typed: (alt-a)\r\n", .{});
//     } else {
//         try writer.print("typed: (unkown escape sequence)\r\n", .{});
//     }
// }

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
