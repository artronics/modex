const std = @import("std");
const dvui = @import("dvui");

var message: []const u8 = "Press the button";

pub const dvui_app: dvui.App = .{
    .config = .{
        .options = .{
            .size = .{ .w = 640, .h = 360 },
            .min_size = .{ .w = 320, .h = 200 },
            .title = "DVUI SDL3 Hello",
            .window_init_options = .{},
        },
    },
    .frameFn = frame,
};

// Use the dvui.App-provided entry points
pub const main = dvui.App.main;
pub const panic = dvui.App.panic;
pub const std_options: std.Options = .{ .logFn = dvui.App.logFn };

fn frame() !dvui.App.Result {
    // Optional scaling helper (good defaults)
    var scaler = dvui.scale(@src(), .{ .scale = &dvui.currentWindow().content_scale, .pinch_zoom = .global }, .{ .rect = .cast(dvui.windowRect()) });
    defer scaler.deinit();

    // Root container for the window content
    var root = dvui.box(@src(), .{ .dir = .vertical}, .{
        .style = .window,
        .expand = .both,
        .background = true,
        // .padding = .{ .l = 12, .t = 12, .r = 12, .b = 12 },
    });
    defer root.deinit();

    // Button: clicking it sets the label text
    if (dvui.button(@src(), "Say Hello", .{}, .{})) {
        message = "Hello, world!";
    }

    // Label: shows current message
    _ = dvui.label(@src(), "yo", .{}, .{});

    // Keep running
    return .ok;
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
