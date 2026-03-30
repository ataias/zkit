//! Project Euler Problem: https://projecteuler.net/problem=5
//!
//! <p>$2520$ is the smallest number that can be divided by each of the numbers
//! from $1$ to $10$ without any remainder.</p>
//!
//! <p>What is the smallest positive number that is <strong
//! class="tooltip">evenly divisible<span class="tooltiptext">divisible with no
//! remainder</span></strong> by all of the numbers from $1$ to $20$?</p>
const std = @import("std");
const Allocator = std.mem.Allocator;
const prime = @import("../math/prime/prime.zig");
const Sieve = prime.Sieve;
const PrimeFactor = Sieve.PrimeFactor;
const maxDistinctPrimeFactors = prime.maxDistinctPrimeFactors;

pub fn smallestNumberDivisibleUpTo(sieve: *const Sieve, limit: u64) Sieve.SieveError!u64 {
    var factors: [maxDistinctPrimeFactors(u64)]PrimeFactor = undefined;
    var factors_count: u64 = 0;
    for (1..limit + 1) |i| {
        var it = sieve.primeFactors(i);
        while (try it.next()) |value| {
            if (indexOf(factors[0..factors_count], value.base)) |index| {
                factors[index].exp = @max(factors[index].exp, value.exp);
            } else {
                factors[factors_count] = value;
                factors_count += 1;
            }
        }
    }
    var product: u64 = 1;
    for (factors[0..factors_count]) |value| {
        product *= std.math.pow(u64, value.base, value.exp);
    }
    return product;
}

fn indexOf(items: []const PrimeFactor, base: u64) ?usize {
    for (items, 0..) |item, i| {
        if (item.base == base) return i;
    }
    return null;
}

test smallestNumberDivisibleUpTo {
    const allocator = std.testing.allocator;
    var sieve = try Sieve.init(allocator, 200);
    defer sieve.deinit();
    const limits = [_]u64{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20 };
    const expected_values = [_]u64{ 1, 2, 6, 12, 60, 60, 420, 840, 2520, 2520, 232792560 };
    for (limits, expected_values) |limit, expected| {
        try std.testing.expectEqual(expected, try smallestNumberDivisibleUpTo(&sieve, limit));
    }
}
