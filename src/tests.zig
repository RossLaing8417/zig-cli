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
test "parse slice" {
    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();

    const writer = buffer.writer();

    const Enum = enum { Some, None };

    const Data = struct {
        int_slice: []i32,
        enum_slice: []Enum,
        string_slice: [][]const u8,
    };
    var result = Data{
        .int_slice = try std.testing.allocator.alloc(i32, 0),
        .enum_slice = try std.testing.allocator.alloc(Enum, 0),
        .string_slice = try std.testing.allocator.alloc([]u8, 0),
    };
    defer {
        std.testing.allocator.free(result.int_slice);
        std.testing.allocator.free(result.enum_slice);
        std.testing.allocator.free(result.string_slice);
    }

    const expected = Data{
        .int_slice = @constCast(&[_]i32{ 1, 2, -3 }),
        .enum_slice = @constCast(&[_]Enum{ .Some, .None }),
        .string_slice = @constCast(&[_][]const u8{ "Foo", "Bar" }),
    };

    var cmd = Cmd{
        .name = "zig-cli",
        .flags = &.{
            .{ .long_name = "int-slice", .required = true, .allow_multiple = true, .binding = Binding.bindSlice(&result.int_slice, std.testing.allocator) },
            .{ .long_name = "enum-slice", .required = true, .allow_multiple = true, .binding = Binding.bindSlice(&result.enum_slice, std.testing.allocator) },
            .{ .long_name = "string-slice", .required = true, .allow_multiple = true, .binding = Binding.bindSlice(&result.string_slice, std.testing.allocator) },
        },
        .action = .{ .run = &dummyFn },
        .error_writer = writer.any(),
    };

    const args = &[_][]const u8{
        "--int-slice",
        "1",
        "--enum-slice",
        "Some",
        "--int-slice",
        "2",
        "--enum-slice",
        "None",
        "--int-slice",
        "-3",
        "--string-slice",
        "Foo",
        "--string-slice",
        "Bar",
    };

    try cmd.runArgs(std.testing.allocator, args, &result);
    try std.testing.expectEqualDeep(expected, result);

    try std.testing.expectEqualStrings("", buffer.items);
}
