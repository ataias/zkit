//! Project Euler Problem: https://projecteuler.net/problem=5
//!
//! <p>$2520$ is the smallest number that can be divided by each of the numbers
//! from $1$ to $10$ without any remainder.</p>
//!
//! <p>What is the smallest positive number that is <strong
//! class="tooltip">evenly divisible<span class="tooltiptext">divisible with no
//! remainder</span></strong> by all of the numbers from $1$ to $20$?</p>
const std = @import("std");

// A way to interpret the problem is understanding that it asks for the Least
// Common Multiple between the numbers.
//
// The basic relationship is lcm(a, b) = |ab| / gcd(a, b)
// Then we need to iterate that for more numbers with lcm(a, b, c) = lcm(lcm(a, b), c)
pub fn smallestNumberDivisibleUpTo(limit: u64) u64 {
    var result: u64 = 1;
    for (1..limit+1) |i| {
        result = std.math.lcm(result, i);
    }
    return result;
}


test smallestNumberDivisibleUpTo {
    const limits = [_]u64{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20 };
    const expected_values = [_]u64{ 1, 2, 6, 12, 60, 60, 420, 840, 2520, 2520, 232792560 };
    for (limits, expected_values) |limit, expected| {
        try std.testing.expectEqual(expected, smallestNumberDivisibleUpTo(limit));
    }
}
