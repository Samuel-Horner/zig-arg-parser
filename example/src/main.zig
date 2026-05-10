const std = @import("std");
const args = @import("zig_arg_parser");

const args_def = args.Definition.init(
    &.{ .{ .name = "foo" } }, // Flags
    &.{ .{ .name = "bar", .default_value = null } }, // Optionals
    &.{ .{ .name = "car" } }, // Positionals
    .{} // Optional Arguments
);

pub fn main(init: std.process.Init) !void {
    const arena = init.arena;

    try args.init(arena.allocator(), init.minimal.args, init.io);
    defer args.deinit();

    const result_set: args.ResultSet(args_def) = args.parse(args_def) catch {
        try args_def.printHelp();
        return; // Dont double print error message
    } orelse {
        return; // If argparse returns null, the program should not continue (a.k.a help argument encountered)
    };

    if (result_set.getFlag(.foo)) std.log.debug("Foo flag encountered!", .{});

    result_set.log();
}
