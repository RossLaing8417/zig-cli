const std = @import("std");

const Binding = @import("binding.zig");
const Parser = @import("parser.zig");

pub fn init(comptime T: type) type {
    return struct {
        const Cmd = @This();

        pub const Context = struct {
            data: *T,
            passthrough_args: []const u8,
        };

        /// Name of the command
        name: []const u8,
        /// List of aliases to use instead of the name
        aliases: ?[][]const u8 = null,
        /// The command version
        version: ?[]const u8 = null,
        /// Message to print out if the command is depreciated
        depreciated: ?[]const u8 = null,
        /// Example of how to use the command
        example: ?[]const u8 = null,
        /// Short description, will be shown in the `help` output
        short_help: ?[]const u8 = null,
        /// Detailed message, will be shown in the `help <command>` output
        long_help: ?[]const u8 = null,
        /// Group under which the command will show in the `help` output
        group: ?[]const u8 = null,
        /// Action to for this command
        action: Action,
        /// Flags
        flags: ?[]const Flag,
        /// Positional arguments
        args: ?[]const PositionalArg = null,

        const Action = union(enum) {
            /// Action this command will run
            run: ActionFn,
            /// Sub commands available to run
            commands: []const Cmd,
        };
        const ActionFn = *const fn (allocator: std.mem.Allocator, cmd: *Cmd, ctx: Context) anyerror!void;

        /// Run the command using the given args slice
        pub fn run(self: *Cmd, allocator: std.mem.Allocator, args: [][]const u8, data: *T) !void {
            const parsed_args, const passthrough_args = try Parser.parse(allocator, args);

            const cmd = self;
            // const action: ActionFn = undefined;

            if (parsed_args.len == 0) switch (cmd.action) {
                .run => {},
                .commands => return Error.MissingSubCommands,
            };

            // TODO: double dash hit -> passthrough_args = if (i < args.len) args[i + 1..] else null;

            // try action(allocator, cmd, .{
            //     .data = data,
            //     .passthrough_args = passthrough_args,
            // });
            _ = data;
            _ = passthrough_args;
        }
    };
}

const Flag = struct {
    long_name: []const u8,
    short_name: ?u8 = null,
    required: bool = false,
    help: ?[]const u8 = null,
    value_name: []const u8 = "VALUE",
    binding: Binding,
};

const PositionalArg = struct {
    name: []const u8,
    required: bool = false,
    // at_least: ?usize = null,
    // at_most: ?usize = null,
    binding: Binding,
};

const Error = error{MissingSubCommands};
