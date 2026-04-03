//! Project Euler Problem: https://projecteuler.net/problem=7
//!
//! <p>By listing the first six prime numbers: $2, 3, 5, 7, 11$, and $13$, we
//! can see that the $6$th prime is $13$.</p>
//!
//! <p>What is the $10\,001$st prime number?</p>

const std = @import("std");
const Sieve = @import("zkit").math.prime.Sieve;
const expectEqual = std.testing.expectEqual;

pub fn main() !void {
    var sieve = try Sieve.init(std.heap.page_allocator, 1_000_000);
    defer sieve.deinit();
    if (getPrimeAtIndex(&sieve, 10000)) |result| {
        std.debug.print("getPrimeAtIndex(10000) = {d}\n", .{result});
    }
}

pub fn getPrimeAtIndex(sieve: *const Sieve, target_index: u64) ?u64 {
    var it = sieve.iterator(.{});
    var index: u64 = 0;
    while (target_index > index) {
        _ = it.next();
        index += 1;
    }
    return it.next();
}

test getPrimeAtIndex {
    const allocator = std.testing.allocator;
    var sieve = try Sieve.init(allocator, 1_000_000);
    defer sieve.deinit();

    try expectEqual(2, getPrimeAtIndex(&sieve, 0));
    try expectEqual(3, getPrimeAtIndex(&sieve, 1));
    try expectEqual(5, getPrimeAtIndex(&sieve, 2));
    try expectEqual(13, getPrimeAtIndex(&sieve, 5));
    try expectEqual(7727, getPrimeAtIndex(&sieve, 980));
    try expectEqual(104_743, getPrimeAtIndex(&sieve, 10000));
}
