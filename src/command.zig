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
    command_list: *const CommandList,
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

    var command_list = try Evaluator.evalArgs(allocator, self, parsed_args, data);
    defer command_list.deinit();

    const commands = command_list.commands.items;

    for (commands) |command| {
        if (command.flags) |flags| {
            for (flags) |flag| {
                if (flag.required and flag.binding.count == 0) {
                    exitMsg(1, "Required flag: {s}\n", .{flag.long_name});
                }
            }
        }
        if (command.args) |args| {
            for (args) |arg| {
                if (arg.required and arg.binding.count == 0) {
                    exitMsg(1, "Required flag: {s}\n", .{arg.name});
                }
            }
        }
    }

    const cmd = commands[commands.len - 1];

    const action = switch (cmd.action) {
        .run => |action| action,
        .commands => Help.printHelpError(&command_list),
    };
    const ctx: Context = .{
        .data = data,
        .passthrough_args = passthrough_args,
        .command_list = &command_list,
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

pub fn exit(status: u8) noreturn {
    std.process.exit(status);
}

pub fn exitMsg(status: u8, comptime fmt: []const u8, args: anytype) noreturn {
    std.debug.print(fmt, args);
    std.process.exit(status);
}

pub const CommandList = struct {
    allocator: std.mem.Allocator,
    commands: std.ArrayList(*const Cmd),

    pub fn init(allocator: std.mem.Allocator, cmd: *const Cmd) !CommandList {
        var command_list = CommandList{
            .allocator = allocator,
            .commands = std.ArrayList(*const Cmd).init(allocator),
        };
        try command_list.append(cmd);
        return command_list;
    }

    pub fn deinit(self: *CommandList) void {
        self.commands.deinit();
    }

    pub fn append(self: *CommandList, cmd: *const Cmd) !void {
        try self.commands.append(cmd);
    }

    pub fn root(self: *const CommandList) *const Cmd {
        std.debug.assert(self.commands.items.len > 0);
        return self.commands.items[0];
    }

    pub fn current(self: *const CommandList) *const Cmd {
        std.debug.assert(self.commands.items.len > 0);
        return self.commands.items[self.commands.items.len - 1];
    }
};

const Evaluator = struct {
    parsed_args: []const Parser.Arg,
    pos: usize = 0,
    i: usize = 0,

    pub fn evalArgs(allocator: std.mem.Allocator, cmd: *const Cmd, parsed_args: []const Parser.Arg, data: *anyopaque) !CommandList {
        var evaluator = Evaluator{
            .parsed_args = parsed_args,
        };

        var command_list = try CommandList.init(allocator, cmd);

        while (evaluator.i < parsed_args.len) : (evaluator.i += 1) {
            const arg = parsed_args[evaluator.i];

            switch (arg) {
                .short => |short| try evaluator.evalShort(&command_list, short),
                .long => |long| try evaluator.evalLong(&command_list, long),
                .positional => |positional| try evaluator.evalPositional(&command_list, positional, data),
            }
        }

        return command_list;
    }

    fn evalShort(self: *Evaluator, command_list: *CommandList, arg: Parser.Arg.Flag) !void {
        const cmd = command_list.current();
        if (cmd.flags) |flags| {
            var found = false;
            for (arg.name, 0..) |name, index| {
                for (flags) |*flag| {
                    if (flag.short_name == null or flag.short_name.? != name) {
                        continue;
                    }
                    if (!flag.allow_multiple and flag.binding.count > 0) {
                        exitMsg(1, "Flag already set: {c}\n", .{name});
                    }
                    // TODO: Probably should do something about the const cast...
                    try @constCast(&flag.binding).parse(blk: {
                        if (index == arg.name.len - 1) {
                            if (consumePositional(arg.value, flag.binding, self.parsed_args[self.i..])) {
                                self.i += 1;
                                break :blk self.parsed_args[self.i].positional;
                            }
                            break :blk arg.value;
                        }
                        break :blk null;
                    });
                    found = true;
                    break;
                }
                if (!found) {
                    switch (name) {
                        'h' => Help.printHelp(command_list),
                        'v' => if (cmd == command_list.root()) Help.printVersion(cmd),
                        else => {},
                    }
                    exitMsg(1, "Unknown flag: {c}\n", .{name});
                }
            }
        } else {
            switch (arg.name[0]) {
                'h' => Help.printHelp(command_list),
                'v' => if (cmd == command_list.root()) Help.printVersion(cmd),
                else => {},
            }
            exitMsg(1, "Unknown flag: {s}\n", .{arg.name});
        }
    }

    fn evalLong(self: *Evaluator, command_list: *CommandList, arg: Parser.Arg.Flag) !void {
        const cmd = command_list.current();
        if (cmd.flags) |flags| {
            var found = false;
            for (flags) |*flag| {
                if (!std.mem.eql(u8, flag.long_name, arg.name)) {
                    continue;
                }
                if (!flag.allow_multiple and flag.binding.count > 0) {
                    exitMsg(1, "Flag already set: {s}\n", .{arg.name});
                }
                // TODO: Probably should do something about the const cast...
                try @constCast(&flag.binding).parse(blk: {
                    if (consumePositional(arg.value, flag.binding, self.parsed_args[self.i..])) {
                        self.i += 1;
                        break :blk self.parsed_args[self.i].positional;
                    }
                    break :blk arg.value;
                });
                found = true;
                break;
            }
            if (!found) {
                if (std.mem.eql(u8, arg.name, "help")) {
                    Help.printHelp(command_list);
                } else if (cmd == command_list.root() and std.mem.eql(u8, arg.name, "version")) {
                    Help.printVersion(cmd);
                }
                exitMsg(1, "Unknown flag: {s}\n", .{arg.name});
            }
        } else {
            if (std.mem.eql(u8, arg.name, "help")) {
                Help.printHelp(command_list);
            } else if (cmd == command_list.root() and std.mem.eql(u8, arg.name, "version")) {
                Help.printVersion(cmd);
            }
            exitMsg(1, "Unknown flag: {s}\n", .{arg.name});
        }
    }

    fn evalPositional(self: *Evaluator, command_list: *CommandList, positional: []const u8, data: *anyopaque) !void {
        const cmd = command_list.current();
        switch (cmd.action) {
            .run => {
                if (cmd.args) |positionals| {
                    if (self.pos < positionals.len) {
                        // TODO: Probably should do something about the const cast...
                        try @constCast(&positionals[self.pos].binding).parse(positional);
                        self.pos += 1;
                    } else {
                        exitMsg(1, "Too many arguments\n", .{});
                    }
                } else {
                    exitMsg(1, "Too many arguments\n", .{});
                }
            },
            .commands => |commands| {
                var found = false;
                for (commands) |*command| {
                    if (!std.mem.eql(u8, positional, command.name)) {
                        continue;
                    }
                    found = true;
                    try command_list.append(command);
                    if (command.init) |initFn| {
                        try initFn(command_list.allocator, command, data);
                    }
                    break;
                }
                if (!found) {
                    exitMsg(1, "Unknown command: {s}\n", .{positional});
                }
            },
        }
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
};
