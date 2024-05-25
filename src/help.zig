const std = @import("std");

const Cmd = @import("command.zig");

pub fn printVersion(cmd: *const Cmd) noreturn {
    const writer = std.io.getStdOut().writer();
    writer.print("{s}\n", .{cmd.version orelse "unknown"}) catch |err| std.debug.print("{}\n", .{err});
    Cmd.exit(0, null);
}
