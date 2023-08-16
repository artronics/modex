const std = @import("std");
const p = @import("pattern.zig");
const Allocator = std.mem.Allocator;
const testing = std.testing;
const expect = testing.expect;

const max_pattern_len = @import("pattern.zig").max_pattern_len;

const path_separator = [_]u8{ '.', '/', '\\' };
const boundary_set = [_]u8{ '_', ' ', '-' } ++ path_separator;

const Score = struct {
    _copy: isize = 0,
    _delete: isize = 0,
    _boundary: isize = 0,
    _kill: isize = 0,
    _straight_acc: isize = 0,

    const qc: isize = 1;
    const qd: isize = -1;
    const qb: isize = -1;
    const qk: isize = -1;
    inline fn qs(x: u5) isize {
        // TODO: evaluate the below with a comparison test
        // the score of 1 will be +2 which, combined by copy will contribute +3 in total. How this will impact short strings scoring?
        // It feels like the score of 0 and 1 should be all 0?

        // return if (x == 0 or x == 1) 0 else (@as(isize, 1) << (x + 1)) - 1;
        return (@as(isize, 1) << (x + 1)) - 2;
    }

    inline fn copy(self: *Score) void {
        self._copy += 1;
    }
    inline fn delete(self: *Score, x: isize) void {
        self._delete += x;
    }
    inline fn boundary(self: *Score) void {
        self._boundary += 1;
    }
    inline fn kill(self: *Score, x: isize) void {
        self._kill += x;
    }
    inline fn straight(self: *Score, x: u5) void {
        self._straight_acc += qs(x);
    }
    pub inline fn score(self: Score) isize {
        return self._copy * qc +
            self._delete * qd +
            self._boundary * qb +
            self._kill * qk +
            self._straight_acc;
    }
    fn string(self: Score, allocator: Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "\ncopy: {d}\ndelete: {d}\nboundary: {d}\nkill: {d}\nstraight_acc: {d}\nSCORE: {d}\n--------", .{
            self._copy,
            self._delete,
            self._boundary,
            self._kill,
            self._straight_acc,
            self.score(),
        });
    }
};

pub fn match(text: []const u8, pattern: []const u8, is_case_sensitive: bool) ?isize {
    return if (matchScore(text, pattern, is_case_sensitive)) |s| s.score() else null;
}

fn matchScore(text: []const u8, pattern: []const u8, is_case_sensitive: bool) ?Score {
    var score = Score{};
    _ = is_case_sensitive;

    var i = text.len;
    var j = pattern.len;
    var last_pj: u8 = undefined;

    var delete_acc: isize = 0;
    var straight_acc: u5 = 0;

    var boundary_slice: ?[]const u8 = null;
    var boundary_end: usize = undefined;

    while (i > 0 and j > 0) : (i -= 1) {
        const ti = text[i - 1];
        const pj = pattern[j - 1];

        if (is_end_boundary(text, i - 1)) {
            boundary_end = i;
        }
        if (is_start_boundary(text, i - 1)) {
            boundary_slice = text[i - 1 .. boundary_end];
        } else {
            boundary_slice = null;
        }

        if (ti == pj) {
            score.copy();
            // copy += 1;
            last_pj = pj;
            straight_acc += 1;

            if (boundary_slice) |b| {
                delete_acc = 0;
                // We don't want to give negative score if straight len is the same as boundary. i.e. full match
                if (straight_acc != b.len) {
                    score.boundary();
                    // boundary += 1;
                }
            }

            j -= 1;
        } else if (last_pj == ti) {
            score.copy();
            // copy += 1;
        } else {
            delete_acc += 1;
            // commit straight
            score.straight(straight_acc);
            // straight_total += (@as(isize, 1) << (straight_acc + 1)) - 2;

            straight_acc = 0;
        }

        if (boundary_slice) |_| {
            score.delete(delete_acc);
            // delete += delete_acc;
            delete_acc = 0;
        }
    }

    return if (j == 0) {
        // commit what is left + kill
        score.straight(straight_acc);
        score.delete(delete_acc);

        // calculate kill
        while (i > 0) : (i -= 1) {
            var ti = text[i - 1];
            if (in_path_sep_set(ti)) break else score.kill(1);
        }

        return score;
    } else null;
}

test "raw match" {
    var r = match("", "", false);
    try expect(r != null);
    r = match("a", "", false);
    try expect(r != null);
    r = match("", "a", false);
    try expect(r == null);

    r = match("a", "a", false);
    try expect(r != null);

    r = match("b", "a", false);
    try expect(r == null);

    r = match("xbyaz", "ba", false);
    try expect(r != null);

    r = match("xbyaz", "ab", false);
    try expect(r == null);
}

pub const Search = struct {
    const Self = @This();

    pub fn search(self: Self, text: []const u8, pattern: []const u8) !?Score {
        _ = self;
        var score = Score{};

        var i = text.len;
        var j = pattern.len;
        var last_pj: u8 = undefined;

        var delete_acc: isize = 0;
        var straight_acc: u5 = 0;

        var boundary: ?[]const u8 = null;
        var boundary_end: usize = undefined;

        while (i > 0 and j > 0) : (i -= 1) {
            const ti = text[i - 1];
            const pj = pattern[j - 1];

            if (is_end_boundary(text, i - 1)) {
                boundary_end = i;
            }
            if (is_start_boundary(text, i - 1)) {
                boundary = text[i - 1 .. boundary_end];
            } else {
                boundary = null;
            }

            if (ti == pj) {
                score.copy();
                last_pj = pj;
                straight_acc += 1;

                if (boundary) |b| {
                    delete_acc = 0;
                    // We don't want to give negative score if straight len is the same as boundary. i.e. full match
                    if (straight_acc != b.len) {
                        score.boundary();
                    }
                }

                j -= 1;
            } else if (last_pj == ti) {
                score.copy();
            } else {
                delete_acc += 1;
                // commit straight
                score.straight(straight_acc);
                straight_acc = 0;
            }

            if (boundary) |_| {
                score.delete(delete_acc);
                delete_acc = 0;
            }
        }

        return if (j == 0) {
            // commit what is left + kill
            score.straight(straight_acc);
            score.delete(delete_acc);
            // calculate kill
            while (i > 0) : (i -= 1) {
                var ti = text[i - 1];
                if (in_path_sep_set(ti)) break else score.kill(1);
            }

            return score;
        } else null;
    }
};

test "match" {
    var s = Search{};

    var r = try s.search("", "");
    try expect(r != null);
    r = try s.search("a", "");
    try expect(r != null);
    r = try s.search("", "a");
    try expect(r == null);

    r = try s.search("a", "a");
    try expect(r != null);

    r = try s.search("b", "a");
    try expect(r == null);

    r = try s.search("xbyaz", "ba");
    try expect(r != null);

    r = try s.search("xbyaz", "ab");
    try expect(r == null);
}

fn in_boundary_set(ch: u8) bool {
    inline for (boundary_set) |b| {
        if (ch == b) return true;
    }
    return false;
}
fn in_path_sep_set(ch: u8) bool {
    inline for (path_separator) |s| {
        if (ch == s) return true;
    }
    return false;
}

const isLower = std.ascii.isLower;
const isUpper = std.ascii.isUpper;
fn is_start_boundary(text: []const u8, i: usize) bool {
    const current = text[i];
    if (i == 0) {
        return !in_boundary_set(current);
    }

    const prev = text[i - 1];
    return (isUpper(current) and isLower(prev)) or in_boundary_set(prev);
}
fn is_end_boundary(text: []const u8, i: usize) bool {
    const current = text[i];
    if (i == text.len - 1) {
        return !in_boundary_set(current);
    }

    const next = text[i + 1];
    return (isLower(current) and isUpper(next)) or in_boundary_set(next);
}

test "is start or end of a boundary?" {
    var s = is_start_boundary("a", 0);
    var e = is_end_boundary("a", 0);
    try expect(s and e);

    s = is_start_boundary("_", 0);
    e = is_end_boundary("_", 0);
    try expect((s or e) == false);

    s = is_start_boundary("Foo", 0);
    e = is_end_boundary("Foo", 2);
    try expect(s and e);

    s = is_start_boundary("Foo", 2);
    e = is_end_boundary("Foo", 0);
    try expect((s or e) == false);

    s = is_start_boundary("FooBar", 3);
    e = is_end_boundary("FooBar", 2);
    try expect(s and e);

    s = is_start_boundary("FooBar", 2);
    e = is_end_boundary("FooBar", 3);
    try expect((s or e) == false);

    s = is_start_boundary("foo_bar", 4);
    e = is_end_boundary("foo_bar", 2);
    try expect(s and e);

    s = is_start_boundary("foo_bar", 3);
    e = is_end_boundary("foo_bar", 3);
    try expect((s or e) == false);

    s = is_start_boundary("BaR", 2);
    e = is_end_boundary("BaR", 2);
    try expect(s and e);
}
test "score" {
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    _ = a;

    var s = Search{};

    { // Copy
        var r = try s.search("axy", "a");
        try expect(r.?._copy == 1);
        r = try s.search("xya", "a");
        try expect(r.?._copy == 1);

        r = try s.search("cbbaa", "cba");
        try expect(r.?._copy == 5);
        // Last pj only counts once because search is terminated when j = 0
        r = try s.search("bbaa", "ba");
        try expect(r.?._copy == 3);

        r = try s.search("baxyax", "ba");
        try expect(r.?._copy == 3);
    }
    { // Straight
        const qs = Score.qs;

        var r = try s.search("a", "a");
        try expect(r.?._straight_acc == qs(1));

        r = try s.search("?abc?", "abc");
        try expect(r.?._straight_acc == qs(3));

        r = try s.search("?abbbccc?", "abc");
        try expect(r.?._straight_acc == qs(3));

        r = try s.search("?ab?cde?", "abcde");
        try expect(r.?._straight_acc == qs(2) + qs(3));

        r = try s.search("?ab_cde?", "abcde");
        try expect(r.?._straight_acc == qs(2) + qs(3));
    }
    { // Delete
        var r = try s.search("?axx", "a");
        try expect(r.?._delete == 2);

        r = try s.search("?bxxaxxx", "ba");
        try expect(r.?._delete == 5);
    }
    { // Boundary aka Chunk
        var r = try s.search("_axx", "a");
        try expect(r.?._delete == 0);
        try expect(r.?._boundary == 1);

        r = try s.search("?_a_b_c", "abc");
        try expect(r.?._delete == 0);
        try expect(r.?._boundary == 0);

        r = try s.search("_axx_foo", "afoo");
        try expect(r.?._delete == 0);
        try expect(r.?._boundary == 1);

        r = try s.search("_axx_fff", "af");
        try expect(r.?._delete == 0);
        try expect(r.?._boundary == 1);

        r = try s.search("_?ax_xbx", "ab");
        try expect(r.?._delete == 4);
        try expect(r.?._boundary == 0);
    }
    { // Kill
        var r = try s.search("a", "a");
        try expect(r.?._kill == 0);

        r = try s.search("xxa???", "a");
        try expect(r.?._kill == 2);

        r = try s.search("??/xxa???", "a");
        try expect(r.?._kill == 2);
    }
}
