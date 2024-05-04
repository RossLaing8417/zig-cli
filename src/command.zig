const std = @import("std");

const Binding = @import("binding.zig");
const Parser = @import("parser.zig");

pub fn init(comptime T: type) type {
    return struct {
        const Cmd = @This();

        pub const Context = struct {
            data: *T,
            passthrough_args: []const []const u8,
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
        const ActionFn = *const fn (allocator: std.mem.Allocator, cmd: *const Cmd, ctx: Context) anyerror!void;

        /// Run the command using the given args slice
        pub fn run(self: *const Cmd, allocator: std.mem.Allocator, command_args: [][]const u8, data: *T) !void {
            const parsed_args, const passthrough_args = try Parser.parse(allocator, command_args);
            defer allocator.free(parsed_args);

            var command_stack = std.ArrayList(*const Cmd).init(allocator);
            defer command_stack.deinit();

            var cmd = self;
            try command_stack.append(cmd);

            var pos: usize = 0;
            var i: usize = 0;
            while (i < parsed_args.len) : (i += 1) {
                const arg = parsed_args[i];

                switch (arg) {
                    .short => |short| {
                        if (cmd.flags) |flags| {
                            var found = false;
                            for (short.name, 0..) |name, index| {
                                for (flags) |flag| {
                                    if (flag.short_name == null or flag.short_name.? != name) {
                                        continue;
                                    }
                                    var binding = flag.binding;
                                    try binding.parse(blk: {
                                        if (index == short.name.len - 1) {
                                            if (consumePositional(short.value, binding, parsed_args[i..])) {
                                                i += 1;
                                                break :blk parsed_args[i].positional;
                                            }
                                            break :blk short.value;
                                        }
                                        break :blk null;
                                    });
                                    found = true;
                                    break;
                                }
                                if (!found) {
                                    std.debug.print("Unknown flag: {c}\n", .{name});
                                    return Error.UnknownFlag;
                                }
                            }
                        } else {
                            std.debug.print("Unknown flag: {s}\n", .{short.name});
                            return Error.UnknownFlag;
                        }
                    },
                    .long => |long| {
                        if (cmd.flags) |flags| {
                            var found = false;
                            for (flags) |flag| {
                                if (!std.mem.eql(u8, flag.long_name, long.name)) {
                                    continue;
                                }
                                var binding = flag.binding;
                                try binding.parse(blk: {
                                    if (consumePositional(long.value, binding, parsed_args[i..])) {
                                        i += 1;
                                        break :blk parsed_args[i].positional;
                                    }
                                    break :blk long.value;
                                });
                                found = true;
                                break;
                            }
                            if (!found) {
                                std.debug.print("Unknown flag: {s}\n", .{long.name});
                                return Error.UnknownFlag;
                            }
                        } else {
                            std.debug.print("Unknown flag: {s}\n", .{long.name});
                            return Error.UnknownFlag;
                        }
                    },
                    .positional => |positional| switch (cmd.action) {
                        .run => {
                            if (cmd.args) |positionals| {
                                if (pos < positionals.len) {
                                    var binding = positionals[pos].binding;
                                    try binding.parse(positional);
                                    pos += 1;
                                } else {
                                    return Error.TooManyArguments;
                                }
                            } else {
                                return Error.TooManyArguments;
                            }
                        },
                        .commands => |commands| {
                            var found = false;
                            for (commands) |*command| {
                                if (!std.mem.eql(u8, positional, command.name)) {
                                    continue;
                                }
                                cmd = command;
                                found = true;
                                try command_stack.append(cmd);
                                break;
                            }
                            if (!found) {
                                std.debug.print("Unknown command: {s}\n", .{positional});
                                return Error.UnknownCommand;
                            }
                        },
                    },
                }
            }

            for (command_stack.items) |command| {
                if (command.flags) |flags| {
                    for (flags) |flag| {
                        if (flag.required and flag.binding.count == 0) {
                            std.debug.print("Required flag: {s}\n", .{flag.long_name});
                            return Error.MissingRequiredFlag;
                        }
                    }
                }
                if (command.args) |args| {
                    for (args) |arg| {
                        if (arg.required and arg.binding.count == 0) {
                            std.debug.print("Required flag: {s}\n", .{arg.name});
                            return Error.MissingRequiredArg;
                        }
                    }
                }
            }

            const action = switch (cmd.action) {
                .run => |action| action,
                .commands => return Error.MissingSubCommands,
            };
            try action(allocator, cmd, .{
                .data = data,
                .passthrough_args = passthrough_args,
            });
        }
    };
}

fn consumePositional(value: ?[]const u8, binding: Binding, args: []const Parser.Arg) bool {
    if (value != null) {
        return false;
    }
    if (binding.metadata.bool == true) {
        return false;
    }
    if (args.len == 1) {
        return false;
    }
    if (args[1] != .positional) {
        return false;
    }
    return true;
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

const Error = error{
    TooManyArguments,
    MissingSubCommands,
    MissingRequiredFlag,
    MissingRequiredArg,
    UnknownFlag,
    UnknownCommand,
};
