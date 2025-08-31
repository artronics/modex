const std = @import("std");
const io = std.io;
const Allocator = std.mem.Allocator;
const Arena = std.heap.ArenaAllocator;

const testing = std.testing;
const test_alloc = std.testing.allocator;
const expectEq = testing.expectEqual;
const print = @import("std").debug.print;

const Rope = struct {
    const Self = @This();

    allocator: Allocator,
    arena: Arena,
    tree: Node,
    buffer: []u8 = undefined,
    max_len: usize,

    pub fn init(alloc: Allocator, max_len: usize) Rope {
        var left = Node.init(null, null);
        const root = Node.init(&left, null);
        const arena = Arena.init(alloc);

        return .{
            .allocator = alloc,
            .arena = arena,
            .tree = root,
            .max_len = max_len,
        };
    }
    pub fn fromSlice(alloc: Allocator, max_len: usize, buf: []const u8) !Rope {
        const buffer: []u8 = try alloc.alloc(u8, buf.len);
        @memcpy(buffer, buf);

        var arena = Arena.init(alloc);
        const arena_alloc = arena.allocator();

        var root = Node.init(null, null);
        try parse(arena_alloc, max_len, &root, buffer);

        return .{
            .allocator = alloc,
            .arena = arena,
            .tree = root,
            .buffer = buffer,
            .max_len = max_len,
        };
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.buffer);
        self.arena.deinit();
    }

    fn split_node(a: Allocator, max_len: usize, node: *Node, buf: []u8) !void {
        if (buf.len <= max_len) {
            const l = try a.create(Node);
            l.* = .{ .l = null, .r = null, .value = .{ .string = buf } };
            node.l = l;

            node.r = null;
            node.value = .{ .weight = buf.len };
            return;
        }
        const mid: usize = @intFromFloat(@round(@as(f64, @floatFromInt(buf.len)) / 2.0));

        const sl = buf[0..mid];
        const l = try a.create(Node);
        l.* = .{ .l = null, .r = null, .value = .{ .string = sl } };
        node.l = l;

        const sr = buf[mid..buf.len];
        const r = try a.create(Node);
        r.* = .{ .l = null, .r = null, .value = .{ .string = sr } };
        node.r = r;

        node.value = .{ .weight = sl.len };
    }
    fn split_leaf(a: Allocator, max_len: usize, node: *Node) !void {
        const buf = node.value.string;
        if (buf.len <= max_len) return;

        const mid: usize = @intFromFloat(@round(@as(f64, @floatFromInt(buf.len)) / 2.0));

        const sl = buf[0..mid];
        const l = try a.create(Node);
        l.* = .{ .l = null, .r = null, .value = .{ .string = sl } };
        node.l = l;

        const sr = buf[mid..buf.len];
        const r = try a.create(Node);
        r.* = .{ .l = null, .r = null, .value = .{ .string = sr } };
        node.r = r;

        node.value = .{ .weight = sl.len };
    }

    fn parse(a: Allocator, max_len: usize, root: *Node, buf: []u8) !void {
        // try split_node(a, max_len, root, buf);
        var l = try a.create(Node);
        l.value = .{.string = buf};
        root.l = l;
        root.value = .{.weight = buf.len};

        var node = root;
        while (node.value.weight < buf.len) : ({
            var tmp = try a.create(Node);
            tmp.l = node;
            node = tmp;
        }) {
            if (node.l != null) {
                const left = node.l.?;
                try split_leaf(a, max_len, left);
                node.value.weight = node.value.weight + left.value.weight;
            }
            if (node.r != null) {
                const right = node.r.?;
                try split_leaf(a, max_len, right);
                node.value.weight = node.value.weight + right.value.weight;
            }
        }
    }
};

const NodeValue = union(enum) {
    weight: usize,
    string: []u8,
};

const Node = struct {
    l: ?*Node,
    r: ?*Node,
    value: NodeValue = .{ .weight = 0 },

    pub fn init(l: ?*Node, r: ?*Node) Node {
        return .{
            .l = l,
            .r = r,
        };
    }
};

test "Node init" {
    const n = Node.init(null, null);

    try testing.expect(n.l == null);
    try testing.expect(n.r == null);
    switch (n.value) {
        NodeValue.weight => |v| try testing.expect(v == 0),
        else => unreachable,
    }
}

test "Rope init file" {
    const tmp = testing.tmpDir(.{});
    const tmp_file_name = "temp_test_file.txt";
    const msg = "hello world!";
    var buf: [msg.len]u8 = undefined;

    const file = blk: {
        var file = try tmp.dir.createFile(tmp_file_name, .{ .read = true });

        var buf_stream = io.bufferedWriter(file.writer());
        const st = buf_stream.writer();
        try st.print(msg, .{});
        try buf_stream.flush();

        break :blk file;
    };
    defer file.close();
    try file.seekTo(0);
    _ = try file.readAll(&buf);

    var r = try Rope.fromSlice(test_alloc, 32, &buf);
    defer r.deinit();
    try testing.expectEqualSlices(u8,  "hello world!", r.tree.l.?.value.string);
}

test "rope" {
    { // hello world! | 12 chars
        const buf = "hello world!";
        var r = try Rope.fromSlice(test_alloc, 6, buf);
        defer r.deinit();
        try expectEq(12, r.tree.value.weight);
        try expect_leaf(&r.tree, "hello ", "world!");
    }
    { // odd number of chars
        const buf = "hello world!!";
        var r = try Rope.fromSlice(test_alloc, 8, buf);
        defer r.deinit();
        try expectEq(13, r.tree.value.weight);
        try expect_leaf(&r.tree, "hello w", "orld!!");
    }
    { // less than max_len
        const buf = "fooo"; // less than 4 chars
        var r = try Rope.fromSlice(test_alloc, 4, buf);
        defer r.deinit();
        try expect_leaf(&r.tree, "fooo", null);
    }
}

fn expect_leaf(node: *Node, l: []const u8, r: ?[]const u8) !void {
    // switch (node.value) {
    //     NodeValue.weight => |v| try testing.expectEqual(l.len, v),
    //     else => unreachable,
    // }
    switch (node.l.?.value) {
        NodeValue.string => |v| try testing.expectEqualSlices(u8, l, v),
        else => unreachable,
    }
    if (r == null) return;
    switch (node.r.?.value) {
        NodeValue.string => |v| try testing.expectEqualSlices(u8, r.?, v),
        else => unreachable,
    }
}
