const std = @import("std");

const Cmd = @This();

const Binding = @import("binding.zig");
const Parser = @import("parser.zig");
const Help = @import("help.zig");

/// Name of the command
name: []const u8,
/// The command version
version: ?[]const u8 = null,
/// Short help to print adjacent to the command name, will be shown in the `help` output
short_help: ?[]const u8 = null,
/// Detailed message to describe the command usage, will be shown in the `help` output
long_help: ?[]const u8 = null,
/// Detailed message to describe the purpose of the command
description: ?[]const u8 = null,
/// Flags
flags: ?[]const Flag = null,
/// Positional arguments
args: ?[]const PositionalArg = null,
/// Function to initialize the command (root cmd only at the moment)
init: ?InitFn = null,
/// Function to deinitialize the command (root cmd only at the moment)
deinit: ?DeinitFn = null,
/// Function to execute before the action
pre_action: ?ActionFn = null,
/// Action to for this command
action: Action,
/// Function to execute after the action
post_action: ?ActionFn = null,

const Flag = struct {
    long_name: []const u8,
    short_name: ?u8 = null,
    required: bool = false,
    allow_multiple: bool = false,
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

pub const Context = struct {
    data: *anyopaque,
    passthrough_args: []const []const u8,
    commands: []*const Cmd,
};

const Action = union(enum) {
    /// Action this command will run
    run: ActionFn,
    /// Sub commands available to run
    commands: []const Cmd,
};

const InitFn = *const fn (allocator: std.mem.Allocator, cmd: *const Cmd, data: *anyopaque) anyerror!void;
const DeinitFn = *const fn (allocator: std.mem.Allocator, cmd: *const Cmd, data: *anyopaque) void;
const ActionFn = *const fn (allocator: std.mem.Allocator, cmd: *const Cmd, ctx: Context) anyerror!void;

/// Run the command using the given args slice
pub fn run(self: *const Cmd, allocator: std.mem.Allocator, data: *anyopaque) !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    return self.runArgs(allocator, if (args.len == 1) args[0..0] else args[1..], data);
}

/// Run the command using the given args slice
pub fn runArgs(self: *const Cmd, allocator: std.mem.Allocator, command_args: [][]const u8, data: *anyopaque) !void {
    const parsed_args, const passthrough_args = try Parser.parse(allocator, command_args);
    defer allocator.free(parsed_args);

    if (self.init) |init| {
        try init(allocator, self, data);
    }
    defer if (self.deinit) |deinit| {
        deinit(allocator, self, data);
    };

    const commands = try self.processArgs(allocator, parsed_args, data);
    defer allocator.free(commands);

    for (commands) |command| {
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

    const cmd = commands[commands.len - 1];

    const action = switch (cmd.action) {
        .run => |action| action,
        .commands => Help.printHelpError(commands),
    };
    const ctx: Context = .{
        .data = data,
        .passthrough_args = passthrough_args,
        .commands = commands,
    };

    for (commands) |command| {
        if (command.pre_action) |pre_action| {
            try pre_action(allocator, command, ctx);
        }
    }

    try action(allocator, cmd, ctx);

    for (0..commands.len) |idx| {
        const command = commands[commands.len - 1 - idx];
        if (command.post_action) |post_action| {
            try post_action(allocator, command, ctx);
        }
    }
}

fn processArgs(self: *const Cmd, allocator: std.mem.Allocator, parsed_args: []const Parser.Arg, data: *anyopaque) ![]*const Cmd {
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
                        for (flags) |*flag| {
                            if (flag.short_name == null or flag.short_name.? != name) {
                                continue;
                            }
                            if (!flag.allow_multiple and flag.binding.count > 0) {
                                std.debug.print("Flag already set: {c}\n", .{name});
                                return Error.FlagAlreadySet;
                            }
                            // TODO: Probably should do something about the const cast...
                            try @constCast(&flag.binding).parse(blk: {
                                if (index == short.name.len - 1) {
                                    if (consumePositional(short.value, flag.binding, parsed_args[i..])) {
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
                            switch (name) {
                                'h' => Help.printHelp(command_stack.items),
                                'v' => if (cmd == self) Help.printVersion(cmd),
                                else => {},
                            }
                            std.debug.print("Unknown flag: {c}\n", .{name});
                            return Error.UnknownFlag;
                        }
                    }
                } else {
                    switch (short.name[0]) {
                        'h' => Help.printHelp(command_stack.items),
                        'v' => if (cmd == self) Help.printVersion(cmd),
                        else => {},
                    }
                    std.debug.print("Unknown flag: {s}\n", .{short.name});
                    return Error.UnknownFlag;
                }
            },
            .long => |long| {
                if (cmd.flags) |flags| {
                    var found = false;
                    for (flags) |*flag| {
                        if (!std.mem.eql(u8, flag.long_name, long.name)) {
                            continue;
                        }
                        if (!flag.allow_multiple and flag.binding.count > 0) {
                            std.debug.print("Flag already set: {s}\n", .{long.name});
                            return Error.FlagAlreadySet;
                        }
                        // TODO: Probably should do something about the const cast...
                        try @constCast(&flag.binding).parse(blk: {
                            if (consumePositional(long.value, flag.binding, parsed_args[i..])) {
                                i += 1;
                                break :blk parsed_args[i].positional;
                            }
                            break :blk long.value;
                        });
                        found = true;
                        break;
                    }
                    if (!found) {
                        if (std.mem.eql(u8, long.name, "help")) {
                            Help.printHelp(command_stack.items);
                        } else if (cmd == self and std.mem.eql(u8, long.name, "version")) {
                            Help.printVersion(cmd);
                        }
                        std.debug.print("Unknown flag: {s}\n", .{long.name});
                        return Error.UnknownFlag;
                    }
                } else {
                    if (std.mem.eql(u8, long.name, "help")) {
                        Help.printHelp(command_stack.items);
                    } else if (cmd == self and std.mem.eql(u8, long.name, "version")) {
                        Help.printVersion(cmd);
                    }
                    std.debug.print("Unknown flag: {s}\n", .{long.name});
                    return Error.UnknownFlag;
                }
            },
            .positional => |positional| switch (cmd.action) {
                .run => {
                    if (cmd.args) |positionals| {
                        if (pos < positionals.len) {
                            // TODO: Probably should do something about the const cast...
                            try @constCast(&positionals[pos].binding).parse(positional);
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
                        if (cmd.init) |init| {
                            try init(allocator, cmd, data);
                        }
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

    return try command_stack.toOwnedSlice();
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

pub fn exit(status: u8, message: ?[]const u8) noreturn {
    if (message) |msg| {
        std.debug.print("{s}\n", .{msg});
    }
    std.process.exit(status);
}

const Error = error{
    TooManyArguments,
    MissingRequiredFlag,
    MissingRequiredArg,
    UnknownFlag,
    UnknownCommand,
    FlagAlreadySet,
};
