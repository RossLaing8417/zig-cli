const std = @import("std");

const Binding = @import("binding.zig");
const Cmd = @import("command.zig");

const Error = Cmd.Error;

fn dummyFn(_: std.mem.Allocator, _: Cmd.Context) !void {}

test "long flag" {
    var result: bool = undefined;

    var cmd = Cmd{
        .name = "zig-cli",
        .flags = &.{
            .{ .long_name = "long", .binding = Binding.bind(&result) },
        },
        .action = .{ .run = &dummyFn },
    };

    const args = &[_][]const u8{
        "--long",
    };

    try cmd.runArgs(std.testing.allocator, args, &result);
    try std.testing.expectEqual(true, result);
}

test "short flag" {
    var result: bool = undefined;

    var cmd = Cmd{
        .name = "zig-cli",
        .flags = &.{
            .{ .long_name = "short", .short_name = 's', .binding = Binding.bind(&result) },
        },
        .action = .{ .run = &dummyFn },
    };

    const args = &[_][]const u8{
        "-s",
    };

    try cmd.runArgs(std.testing.allocator, args, &result);
    try std.testing.expectEqual(true, result);
}

test "missing required flag" {
    var result: bool = undefined;

    var cmd = Cmd{
        .name = "zig-cli",
        .flags = &.{
            .{ .long_name = "flag", .required = true, .binding = Binding.bind(&result) },
        },
        .action = .{ .run = &dummyFn },
    };

    const args = &[_][]const u8{};

    try std.testing.expectError(Error.MissingRequiredFlag, cmd.runArgs(std.testing.allocator, args, &result));
}

test "missing required arg" {
    var result: bool = undefined;

    var cmd = Cmd{
        .name = "zig-cli",
        .args = &.{
            .{ .name = "name", .required = true, .binding = Binding.bind(&result) },
        },
        .action = .{ .run = &dummyFn },
    };

    const args = &[_][]const u8{};

    try std.testing.expectError(Error.MissingRequiredArg, cmd.runArgs(std.testing.allocator, args, &result));
}

test "flag already set" {
    var result: bool = undefined;

    var cmd = Cmd{
        .name = "zig-cli",
        .flags = &.{
            .{ .long_name = "flag", .short_name = 'f', .binding = Binding.bind(&result) },
        },
        .action = .{ .run = &dummyFn },
    };

    const args = &[_][]const u8{
        "--flag",
        "-f",
    };

    try std.testing.expectError(Error.FlagAlreadySet, cmd.runArgs(std.testing.allocator, args, &result));
}

test "unknown flag" {
    var result: bool = undefined;

    var cmd = Cmd{
        .name = "zig-cli",
        .flags = &.{
            .{ .long_name = "flag", .short_name = 'f', .binding = Binding.bind(&result) },
        },
        .action = .{ .run = &dummyFn },
    };

    const args = &[_][]const u8{
        "--unknown",
    };

    try std.testing.expectError(Error.UnknownFlag, cmd.runArgs(std.testing.allocator, args, &result));
}

test "unknown command" {
    var result: bool = undefined;

    var cmd = Cmd{
        .name = "zig-cli",
        .action = .{ .commands = &.{
            .{
                .name = "command",
                .action = .{ .run = &dummyFn },
            },
        } },
    };

    const args = &[_][]const u8{
        "unknown",
    };

    try std.testing.expectError(Error.UnknownCommand, cmd.runArgs(std.testing.allocator, args, &result));
}

test "parse flags success" {
    const Enum = enum { Some };

    const Data = struct {
        signed: i32 = undefined,
        unsigned: u32 = undefined,
        float: f32 = undefined,
        bool: bool = undefined,
        string: []const u8 = undefined,
        @"enum": Enum = undefined,
    };
    var result = Data{};
    const expected = Data{
        .signed = -123,
        .unsigned = 123,
        .float = 12.34,
        .bool = false,
        .string = "abc",
        .@"enum" = .Some,
    };

    var cmd = Cmd{
        .name = "zig-cli",
        .flags = &.{
            .{ .long_name = "signed", .required = true, .binding = Binding.bind(&result.signed) },
            .{ .long_name = "unsigned", .required = true, .binding = Binding.bind(&result.unsigned) },
            .{ .long_name = "float", .required = true, .binding = Binding.bind(&result.float) },
            .{ .long_name = "bool", .required = true, .binding = Binding.bind(&result.bool) },
            .{ .long_name = "string", .required = true, .binding = Binding.bind(&result.string) },
            .{ .long_name = "enum", .required = true, .binding = Binding.bind(&result.@"enum") },
        },
        .action = .{ .run = &dummyFn },
    };

    const args = &[_][]const u8{
        "--signed",
        "-123",
        "--unsigned",
        "123",
        "--float",
        "12.34",
        "--bool=false",
        "--string",
        "abc",
        "--enum",
        "Some",
    };

    try cmd.runArgs(std.testing.allocator, args, &result);
    try std.testing.expectEqualDeep(expected, result);
}
