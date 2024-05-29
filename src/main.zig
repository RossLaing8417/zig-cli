const std = @import("std");

const Binding = @import("binding.zig");
const Cmd = @import("command.zig");

const Options = struct {
    bool: ?bool = null,
    signed: i32 = 0,
    unsigned: u32 = 0,
    float: f32 = 0,
    slice: ?[]const u8 = null,
    sub: struct { bool: bool = false } = .{},
    other: struct { bool: bool = false } = .{},
    persistent: ?bool = null,
};

pub fn main() !void {
    var options: Options = .{};

    var cmd = Cmd{
        .name = "zig-cli",
        .version = "0.69.420",
        .short_help = "making things go pop",
        .long_help =
        \\sub [-S | --sub-command]
        \\other [-O | --other-command]
        ,
        .description =
        \\type things and see what happens
        ,
        .flags = &.{
            .{ .long_name = "bool", .short_name = 'b', .help = "bool flag", .binding = Binding.bind(&options.bool) },
            .{ .long_name = "signed", .short_name = 'i', .help = "signed flag", .binding = Binding.bind(&options.signed) },
            .{ .long_name = "unsigned", .short_name = 'u', .help = "unsigned flag", .binding = Binding.bind(&options.unsigned) },
            .{ .long_name = "float", .short_name = 'f', .help = "float flag", .binding = Binding.bind(&options.float) },
            .{ .long_name = "slice", .short_name = 's', .help = "slice flag", .binding = Binding.bind(&options.slice) },
            .{ .long_name = "tiny", .binding = Binding.bind(&options.bool) },
            .{ .long_name = "short", .short_name = 't', .binding = Binding.bind(&options.bool) },
            .{ .long_name = "longish", .binding = Binding.bind(&options.bool) },
            .{ .long_name = "really-long", .short_name = 'l', .binding = Binding.bind(&options.bool) },
            .{ .long_name = "persistent", .short_name = 'p', .binding = Binding.bind(&options.persistent) },
        },
        // Action is either a function to run or a list of possible sub commands
        // .action = .{ .run = &execute },
        .init = &init,
        .deinit = &deinit,
        .pre_action = &pre,
        .post_action = &post,
        .action = .{ .commands = &.{
            .{
                .name = "sub",
                .short_help = "magic things",
                .long_help =
                \\nothing to see here...
                ,
                .description =
                \\nothing to see here...
                ,
                .flags = &.{
                    .{ .long_name = "sub-command", .short_name = 'S', .binding = Binding.bind(&options.sub.bool) },
                },
                .action = .{ .run = &execute },
            },
            .{
                .name = "other",
                .short_help = "good times",
                .long_help =
                \\nothing to see here...
                ,
                .description =
                \\nothing to see here...
                ,
                .flags = &.{
                    .{ .long_name = "other-command", .short_name = 'O', .binding = Binding.bind(&options.other.bool) },
                },
                .action = .{ .run = &execute },
            },
        } },
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    try cmd.run(allocator, &options);
}

fn init(_: std.mem.Allocator, _: *const Cmd, _: *anyopaque) !void {
    std.debug.print("init\n", .{});
}

fn deinit(_: std.mem.Allocator, _: *const Cmd, _: *anyopaque) void {
    std.debug.print("deinit\n", .{});
}

fn pre(_: std.mem.Allocator, _: *const Cmd, _: Cmd.Context) !void {
    std.debug.print("pre\n", .{});
}

fn post(_: std.mem.Allocator, _: *const Cmd, _: Cmd.Context) !void {
    std.debug.print("post\n", .{});
}

fn execute(_: std.mem.Allocator, _: *const Cmd, ctx: Cmd.Context) !void {
    const options: *Options = @ptrCast(@alignCast(ctx.data));
    std.debug.print("OMG!\n{any}\n", .{options});
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
