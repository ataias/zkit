//! Project Euler Problem: https://projecteuler.net/problem=1
//! <p>If we list all the natural numbers below $10$ that are multiples of $3$ or $5$, we get $3, 5, 6$ and $9$. The sum of these multiples is $23$.</p>
//! <p>Find the sum of all the multiples of $3$ or $5$ below $1000$.</p>
const std = @import("std");

pub fn main() void {
    std.debug.print("multiples(1000) = {d}\n", .{multiples(1000)});
}

pub fn multiples(limit: u64) u64 {
    var sum: u64 = 0;
    for (1..limit) |i| {
        if (i % 3 == 0 or i % 5 == 0) {
            sum += i;
        }
    }
    return sum;
}

test multiples {
    try std.testing.expectEqual(23, multiples(10));
    try std.testing.expectEqual(233168, multiples(1000));
}
