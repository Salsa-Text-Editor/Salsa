const std = @import("std");
const posix = std.posix;
const fs = std.fs;

pub const TerminalWindow = struct {
    rows: u16,
    columns: u16,
    tty_fd: posix.system.fd_t,

    const Self = @This();

    fn getWinSize(tty_fd: posix.system.fd_t) !posix.winsize {
        var win_size = posix.winsize{
            .row = 0,
            .col = 0,
            .xpixel = 0,
            .ypixel = 0,
        };

        const err = posix.system.ioctl(tty_fd, posix.T.IOCGWINSZ, @intFromPtr(&win_size));
        if (posix.errno(err) == .SUCCESS) {
            return win_size;
        }

        return @errorFromInt(@intFromEnum(posix.errno(err)));
    }

    pub fn init(tty_fd: posix.system.fd_t) !Self {
        const winsize = try getWinSize(tty_fd);
        return Self{ .columns = winsize.col, .rows = winsize.row - 1, .tty_fd = tty_fd };
    }

    pub fn update(self: *Self) !void {
        const winsize = try getWinSize(self.tty_fd);
        if (winsize.col != self.columns or winsize.row != self.rows) {
            self.*.columns = winsize.col;
            self.*.rows = winsize.row - 1;
        }
    }
};

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
