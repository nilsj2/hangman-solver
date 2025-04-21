const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "hangman-solver",
        .root_module = exe_mod,
    });

    const language = b.option(enum { en, se }, "language", "language for dictionary that solver uses") orelse .en;
    const cwd = std.fs.cwd();
    const words_file = try cwd.openFile(b.fmt("words/{s}.txt", .{@tagName(language)}), .{});
    const words_txt = try words_file.readToEndAlloc(b.allocator, 100_000_000);

    var word_list: std.ArrayListUnmanaged([]const u8) = .empty;
    var word_iterator = std.mem.splitScalar(u8, words_txt, '\n');
    while (word_iterator.next()) |word| {
        word_list.append(b.allocator, word) catch unreachable;
    }

    const options = b.addOptions();
    options.addOption([]const []const u8, "words", word_list.items);

    exe.root_module.addOptions("words", options);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
