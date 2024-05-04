const std = @import("std");

const Binding = @import("binding.zig");
const Command = @import("command.zig");

const Options = struct {
    bool: ?bool = null,
    signed: i32 = 0,
    unsigned: u32 = 0,
    float: f32 = 0,
    slice: ?[]const u8 = null,
};

const Cmd = Command.init(Options);

pub fn main() !void {
    var options: Options = .{};

    var cmd = Cmd{
        .name = "woot",
        .action = .{ .run = &execute },
        .flags = &.{
            .{ .long_name = "bool", .short_name = 'b', .binding = Binding.bindTo(&options.bool) },
            .{ .long_name = "signed", .short_name = 'i', .binding = Binding.bindTo(&options.signed) },
            .{ .long_name = "unsigned", .short_name = 'u', .binding = Binding.bindTo(&options.unsigned) },
            .{ .long_name = "float", .short_name = 'f', .binding = Binding.bindTo(&options.float) },
            .{ .long_name = "slice", .short_name = 's', .binding = Binding.bindTo(&options.slice) },
        },
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    try cmd.run(allocator, if (args.len == 1) args[0..0] else args[1..], &options);
}

fn execute(_: std.mem.Allocator, _: *const Cmd, ctx: Cmd.Context) !void {
    std.debug.print("OMG!\n{any}\n", .{ctx.data});
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
