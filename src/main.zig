const std = @import("std");
const print = std.debug.print;
const builtin = @import("builtin");

const words = @import("words").words;

/// Usage: solver <WORD_LENGTH>
/// Then a back and forth until solution
pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    const stdin = std.io.getStdIn().reader();

    var arg_iterator = try std.process.argsWithAllocator(std.heap.page_allocator);
    _ = arg_iterator.next().?;
    const number_string = arg_iterator.next() orelse return error.NoWordLengthProvided;
    if (arg_iterator.next() != null) {
        return error.TooManyArgs;
    }
    const length = try std.fmt.parseInt(usize, number_string, 10);

    var buffer = [_]u8{0} ** 50; // Longest swedish word is 48
    const mask = buffer[0..length];
    var not_present: std.StaticBitSet(256) = .initEmpty();

    var tries: u32 = 0;
    game_loop: while (true) : (tries += 1) {
        const result = try calculateBest(mask, not_present);
        if (result.answer) |answer| {
            try stdout.print("Matched word: {s} in {} tries\n", .{ answer, tries });
            try bw.flush();
            break :game_loop;
        }
        const suggested_char = result.guess;
        try stdout.print("Best guess: '{c}({})'\n", .{ suggested_char, suggested_char });

        _ = try stdout.write("Current solution:\n");
        for (mask) |char| {
            try stdout.writeByte(if (char == 0) '_' else char);
        }
        _ = try stdout.write("\nEnter new solution:\n");
        try bw.flush();
        var new_buffer = [_]u8{0} ** 50; // Longest sewdish word is 48
        const raw_str = try stdin.readUntilDelimiter(&new_buffer, '\n');
        const new_mask_str = std.mem.trim(u8, raw_str, &std.ascii.whitespace);

        if (new_mask_str.len == 0) {
            not_present.setValue(suggested_char, true);
            continue;
        }
        std.mem.replaceScalar(u8, @constCast(new_mask_str), '_', 0);

        var something_changed = false;
        for (mask, new_mask_str, 0..) |old, new, i| {
            if (old != new) {
                mask[i] = new;
                something_changed = true;
            }
        }
        if (!something_changed) {
            not_present.setValue(suggested_char, true);
        }
    }
}

fn calculateBest(mask: []u8, not_present: std.StaticBitSet(256)) !struct { guess: u8, answer: ?[]const u8 } {
    var matching_word_count: usize = 0;
    var char_counts = [_]u32{0} ** 256;
    var last_match: []const u8 = undefined;

    word_loop: for (words) |word| {
        if (word.len != mask.len) {
            continue;
        }
        for (word, mask) |actual, expected| {
            if (!(expected == 0 or std.ascii.toLower(actual) == expected) or not_present.isSet(actual)) {
                continue :word_loop;
            }
        }
        matching_word_count += 1;
        for (word) |char| {
            char_counts[char] += 1;
        }
        last_match = word;
    }

    if (matching_word_count == 1) {
        return .{ .guess = 0, .answer = last_match };
    }

    const suggested_char = blk: {
        var correct_chars: std.StaticBitSet(256) = .initEmpty();
        for (mask) |char| {
            if (char != 0) {
                correct_chars.setValue(char, true);
            }
        }
        var to_suggest: u8 = undefined;
        var suggestion_occured: u32 = 0;
        for (char_counts, 0..) |occurs, char| {
            const truncated: u8 = @truncate(char);
            if (occurs > suggestion_occured and !correct_chars.isSet(char)) {
                to_suggest = truncated;
                suggestion_occured = occurs;
            }
        }
        break :blk to_suggest;
    };

    return .{ .guess = suggested_char, .answer = null };
}
