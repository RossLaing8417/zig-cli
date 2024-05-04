const std = @import("std");

const Binding = @import("binding.zig");
const Command = @import("command.zig");

const Options = struct {
    eish: ?bool = null,
};

const Cmd = Command.init(Options);

pub fn main() !void {
    var options: Options = .{};

    var cmd = Cmd{
        .name = "woot",
        .action = .{ .run = &execute },
        .flags = &.{
            .{ .long_name = "enabled", .binding = Binding.bindTo(&options.eish) },
        },
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    try cmd.run(allocator, args, &options);
}

fn execute(_: std.mem.Allocator, _: *Cmd, ctx: Cmd.Context) !void {
    std.debug.print("OMG!\n{?}\n", .{ctx.data.eish});
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
