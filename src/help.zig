const std = @import("std");

const Cmd = @import("command.zig");
const CommandList = Cmd.CommandList;

pub fn printVersion(writer: std.io.AnyWriter, cmd: *const Cmd) !void {
    try writer.print("{s}\n", .{cmd.version orelse "unknown"});
}

pub fn printHelp(writer: std.io.AnyWriter, command_list: *const CommandList) !void {
    const commands = command_list.commands.items;
    const exec_cmd = command_list.current();
    const is_root_cmd = exec_cmd == command_list.root();

    try writer.writeAll("NAME:\n    ");
    for (commands, 0..) |cmd, i| {
        if (i != 0) {
            try writer.writeByte(' ');
        }
        try writer.writeAll(cmd.name);
    }

    if (exec_cmd.short_help) |help| {
        try writer.print(" - {s}", .{help});
    }

    try writer.writeByte('\n');

    if (exec_cmd.long_help) |help| {
        try writer.writeAll("\nUSAGE:\n");
        try printIndented(writer, help);
    }

    if (is_root_cmd) {
        if (exec_cmd.version) |version| {
            try writer.writeAll("\nVERSION:\n");
            try printIndented(writer, version);
        }
    }

    if (exec_cmd.description) |description| {
        try writer.writeAll("\nDESCRIPTION:\n");
        try printIndented(writer, description);
    }

    if (exec_cmd.action == .commands) {
        try writer.writeAll("\nCOMMANDS:\n");
        var max: usize = 0;
        for (exec_cmd.action.commands) |cmd| {
            max = @max(cmd.name.len, max);
        }
        for (exec_cmd.action.commands) |cmd| {
            try writer.print("    {s}", .{cmd.name});
            if (cmd.short_help) |help| {
                try writer.writeByteNTimes(' ', max - cmd.name.len);
                try writer.print(" - {s}", .{help});
            }
            try writer.writeByte('\n');
        }
    }

    //TODO: Persistent flags
    if (exec_cmd.flags) |flags| {
        try writer.writeAll("\nOPTIONS:\n");
        var max: usize = 0;
        for (flags) |flag| {
            var len = flag.long_name.len;
            if (!flag.binding.metadata.bool) {
                len += 1 + flag.value_name.len;
            }
            if (flag.short_name) |_| {
                len += 4;
                if (!flag.binding.metadata.bool) {
                    len += 1 + flag.value_name.len;
                }
            }
            max = @max(len, max);
        }
        for (flags) |flag| {
            var len: usize = max + 1;
            try writer.print("    --{s}", .{flag.long_name});
            len -= flag.long_name.len;
            if (!flag.binding.metadata.bool) {
                try writer.print(" {s}", .{flag.value_name});
                len -= 1 + flag.value_name.len;
            }
            if (flag.short_name) |name| {
                try writer.print(", -{c}", .{name});
                len -= 4;
                if (!flag.binding.metadata.bool) {
                    try writer.print(" {s}", .{flag.value_name});
                    len -= 1 + flag.value_name.len;
                }
            }
            if (flag.help) |help| {
                try writer.writeByteNTimes(' ', len);
                try writer.writeAll(help);
            }
            try writer.writeByte('\n');
        }
    }
}

fn printCommandShortHelp(writer: std.fs.File.Writer, command_list: *const CommandList) !void {
    const commands = command_list.commands.items;
    const exec_cmd = command_list.current();
    for (commands, 0..) |cmd, i| {
        if (i != 0) {
            try writer.writeByte(' ');
        }
        try writer.writeAll(cmd.name);
    }

    if (exec_cmd.short_help) |help| {
        try writer.print(" - {s}", .{help});
    }

    try writer.writeByte('\n');

    if (exec_cmd.long_help) |help| {
        try writer.print("\n{s}\n", .{help});
    }

    if (exec_cmd.description) |description| {
        try writer.print("\n{s}\n", .{description});
    }
}

fn printIndented(writer: std.io.AnyWriter, message: []const u8) !void {
    var itr = std.mem.splitSequence(u8, message, "\n");
    while (itr.next()) |line| {
        try writer.print("    {s}\n", .{line});
    }
}
