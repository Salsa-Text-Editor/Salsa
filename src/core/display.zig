const Buffer = struct {
    var currentLine: u32 = 0;
    var currentChar: u32 = 0;
    var lines: []Line = undefined;

    pub fn getCurrentLine() !Line {
        if (currentLine > lines.len) {
            return error.OUT_OF_BOUNDS;
        }
        return lines[currentLine];
    }

    pub fn getCurrentChar() !u8 {
        return try getCurrentLine()[currentChar];
    }
};

const Line = struct {
    var chars = []u8;
};
