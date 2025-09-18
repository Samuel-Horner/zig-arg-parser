pub const packages = struct {
    pub const @".." = struct {
        pub const build_root = "/home/sam/dox/projects/zig-arg-parser/example/..";
        pub const build_zig = @import("..");
        pub const deps: []const struct { []const u8, []const u8 } = &.{
        };
    };
};

pub const root_deps: []const struct { []const u8, []const u8 } = &.{
    .{ "zig_arg_parser", ".." },
};
