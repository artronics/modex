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
        try build(arena_alloc, max_len, &root, buffer);

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

    fn build_sub_tree(a: Allocator, max_len: usize, buf: []u8) !*Node {
        const n = try a.create(Node);
        n.l = null;
        n.r = null;

        if (buf.len <= max_len) {
            n.value = .{ .string = buf };
            return n;
        }

        const mid: usize = @intFromFloat(@round(@as(f64, @floatFromInt(buf.len)) / 2.0));
        const left_buf = buf[0..mid];
        const right_buf = buf[mid..];

        const left_node = try build_sub_tree(a, max_len, left_buf);
        const right_node = try build_sub_tree(a, max_len, right_buf);

        n.l = left_node;
        n.r = right_node;
        n.value = .{ .weight = left_buf.len };
        return n;
    }

    fn build(a: Allocator, max_len: usize, root: *Node, buf: []u8) !void {
        const node = try a.create(Node);
        const mid: usize = @intFromFloat(@round(@as(f64, @floatFromInt(buf.len)) / 2.0));
        const left_node = try build_sub_tree(a, max_len, buf[0..mid]);
        const right_node = try build_sub_tree(a, max_len, buf[mid..]);

        node.l = left_node;
        node.r = right_node;
        node.value = .{ .weight = mid };

        root.l = node;
        root.r = null;
        root.value = .{ .weight = buf.len };
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
    try expect_leaf(r.tree.l.?, "hello ", "world!");
}

test "rope" {
    { // hello world! | 12 chars
        const buf = "hello world!";
        var r = try Rope.fromSlice(test_alloc, 6, buf);
        defer r.deinit();
        try expectEq(12, r.tree.value.weight);
        try expect_leaf(r.tree.l.?, "hello ", "world!");
    }
    { // odd number of chars
        const buf = "hello world!!";
        var r = try Rope.fromSlice(test_alloc, 8, buf);
        defer r.deinit();
        try expectEq(13, r.tree.value.weight);
        try expect_leaf(r.tree.l.?, "hello w", "orld!!");
    }
}

fn expect_leaf(node: *Node, l: []const u8, r: ?[]const u8) !void {
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
