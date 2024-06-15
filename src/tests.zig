const std = @import("std");

const Binding = @import("binding.zig");
const Cmd = @import("command.zig");

const Error = Cmd.Error;

fn dummyFn(_: std.mem.Allocator, _: Cmd.Context) !void {}

test "long flag" {
    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();

    const writer = buffer.writer();

    var result: bool = undefined;

    var cmd = Cmd{
        .name = "zig-cli",
        .flags = &.{
            .{ .long_name = "long", .required = true, .binding = Binding.bind(&result) },
        },
        .action = .{ .run = &dummyFn },
        .error_writer = writer.any(),
    };

    const args = &[_][]const u8{
        "--long",
    };

    try cmd.runArgs(std.testing.allocator, args, &result);
    try std.testing.expectEqual(true, result);

    try std.testing.expectEqualStrings("", buffer.items);
}

test "short flag" {
    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();

    const writer = buffer.writer();

    var result: bool = undefined;

    var cmd = Cmd{
        .name = "zig-cli",
        .flags = &.{
            .{ .long_name = "short", .short_name = 's', .required = true, .binding = Binding.bind(&result) },
        },
        .action = .{ .run = &dummyFn },
        .error_writer = writer.any(),
    };

    const args = &[_][]const u8{
        "-s",
    };

    try cmd.runArgs(std.testing.allocator, args, &result);
    try std.testing.expectEqual(true, result);

    try std.testing.expectEqualStrings("", buffer.items);
}

test "missing required flag" {
    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();

    const writer = buffer.writer();

    var result: bool = undefined;

    var cmd = Cmd{
        .name = "zig-cli",
        .flags = &.{
            .{ .long_name = "flag", .required = true, .binding = Binding.bind(&result) },
        },
        .action = .{ .run = &dummyFn },
        .error_writer = writer.any(),
    };

    const args = &[_][]const u8{};

    try std.testing.expectError(Error.MissingRequiredFlag, cmd.runArgs(std.testing.allocator, args, &result));

    try std.testing.expectEqualStrings("Required flag: flag\n", buffer.items);
}

test "missing required arg" {
    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();

    const writer = buffer.writer();

    var result: bool = undefined;

    var cmd = Cmd{
        .name = "zig-cli",
        .args = &.{
            .{ .name = "name", .required = true, .binding = Binding.bind(&result) },
        },
        .action = .{ .run = &dummyFn },
        .error_writer = writer.any(),
    };

    const args = &[_][]const u8{};

    try std.testing.expectError(Error.MissingRequiredArg, cmd.runArgs(std.testing.allocator, args, &result));

    try std.testing.expectEqualStrings("Required arg: name\n", buffer.items);
}

test "flag already set" {
    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();

    const writer = buffer.writer();

    var result: bool = undefined;

    var cmd = Cmd{
        .name = "zig-cli",
        .flags = &.{
            .{ .long_name = "flag", .short_name = 'f', .required = true, .binding = Binding.bind(&result) },
        },
        .action = .{ .run = &dummyFn },
        .error_writer = writer.any(),
    };

    const args = &[_][]const u8{
        "--flag",
        "-f",
    };

    try std.testing.expectError(Error.FlagAlreadySet, cmd.runArgs(std.testing.allocator, args, &result));

    try std.testing.expectEqualStrings("Flag already set: f\n", buffer.items);
}

test "unknown flag" {
    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();

    const writer = buffer.writer();

    var result: bool = undefined;

    var cmd = Cmd{
        .name = "zig-cli",
        .flags = &.{
            .{ .long_name = "flag", .short_name = 'f', .required = true, .binding = Binding.bind(&result) },
        },
        .action = .{ .run = &dummyFn },
        .error_writer = writer.any(),
    };

    const args = &[_][]const u8{
        "--unknown",
    };

    try std.testing.expectError(Error.UnknownFlag, cmd.runArgs(std.testing.allocator, args, &result));

    try std.testing.expectEqualStrings("Unknown flag: unknown\n", buffer.items);
}

test "unknown command" {
    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();

    const writer = buffer.writer();

    var result: bool = undefined;

    var cmd = Cmd{
        .name = "zig-cli",
        .action = .{ .commands = &.{
            .{
                .name = "command",
                .action = .{ .run = &dummyFn },
            },
        } },
        .error_writer = writer.any(),
    };

    const args = &[_][]const u8{
        "unknown",
    };

    try std.testing.expectError(Error.UnknownCommand, cmd.runArgs(std.testing.allocator, args, &result));

    try std.testing.expectEqualStrings("Unknown command: unknown\n", buffer.items);
}

test "parse flags success" {
    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();

    const writer = buffer.writer();

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
        .error_writer = writer.any(),
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

    try std.testing.expectEqualStrings("", buffer.items);
}

test "generate shell completion" {
    var out_buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer out_buffer.deinit();

    var err_buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer err_buffer.deinit();

    const out_writer = out_buffer.writer();
    const err_writer = err_buffer.writer();

    var cmd = Cmd{
        .name = "zig-cli",
        .action = .{ .run = &dummyFn },
        .writer = out_writer.any(),
        .error_writer = err_writer.any(),
    };

    const args = &[_][]const u8{
        "--generate-shell-completion",
        "bash",
    };

    try cmd.runArgs(std.testing.allocator, args, &cmd);

    // try std.testing.expectEqualStrings("", out_buffer.items);
    try std.testing.expectEqualStrings("", err_buffer.items);
}
