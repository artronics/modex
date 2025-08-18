const std = @import("std");
const io = std.io;
const Allocator = std.mem.Allocator;

const Rope = struct {
    const Self = @This();

    allocator: Allocator,
    tree: Node,
    buffer: []u8 = undefined,

    pub fn init(alloc: Allocator) Rope {
        var left = Node.init(null, null);
        const root = Node.init(&left, null);

        return .{ .allocator = alloc, .tree = root };
    }
    pub fn fromSlice(alloc: Allocator, buf: []u8) !Rope {
        const buffer: []u8 = try alloc.alloc(u8, buf.len);
        @memcpy(buffer, buf);

        var left = Node.init(null, null);
        left.value = NodeValue{ .string = buffer };
        const root = Node.init(&left, null);

        return .{ .allocator = alloc, .tree = root, .buffer = buffer };
    }
    pub fn deinit(self: Self) void {
        self.allocator.free(self.buffer);
    }
};

const NodeValue = union(enum) {
    weight: u32,
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

const testing = std.testing;
const test_alloc = std.testing.allocator;
const expect = testing.expect;

test "Node init" {
    const n = Node.init(null, null);

    try expect(n.l == null);
    try expect(n.r == null);
    switch (n.value) {
        NodeValue.weight => |v| try expect(v == 0),
        else => unreachable,
    }
}

test "Rope init" {
    const tmp = testing.tmpDir(.{});
    const tmp_file_name = "temp_test_file.txt";
    const msg = "hello world!";
    var buf: [msg.len]u8 = undefined;

    const file = blk: {
        var file = try tmp.dir.createFile(tmp_file_name, .{ .read = true });

        var buf_stream = io.bufferedWriter(file.writer());
        const st = buf_stream.writer();
        try st.print("hello world!", .{});
        try buf_stream.flush();

        break :blk file;
    };
    defer file.close();
    try file.seekTo(0);
    _ = try file.readAll(&buf);

    var r = try Rope.fromSlice(test_alloc, &buf);
    defer r.deinit();
    switch (r.tree.l.?.value) {
        NodeValue.string => |v| try testing.expectEqualSlices(u8, "hello world!", v),
        else => unreachable,
    }
}
