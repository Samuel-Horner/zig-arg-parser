const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zig_arg_parser = b.addModule("zig-arg-parser", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zig_arg_parser",
        .root_module = zig_arg_parser,
    });

    b.installArtifact(lib);

    { // Test Step
        const lib_unit_tests = b.addTest(.{
            .root_module = zig_arg_parser,
        });

        const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_lib_unit_tests.step);
    }

    { // Docs Step
        const lib_docs = b.addInstallDirectory(.{
            .source_dir = lib.getEmittedDocs(),
            .install_dir = .prefix,
            .install_subdir = "docs",
        });

        const docs_step = b.step("docs", "Emit documentation");
        docs_step.dependOn(&lib_docs.step);
    }
}
