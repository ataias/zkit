//! Project Euler Problem: https://projecteuler.net/problem=6
//!
//! <p>The sum of the squares of the first ten natural numbers is,</p>
//!
//! $$1^2 + 2^2 + ... + 10^2 = 385.$$
//!
//! <p>The square of the sum of the first ten natural numbers is,</p>
//!
//! $$(1 + 2 + ... + 10)^2 = 55^2 = 3025.$$
//!
//! <p>Hence the difference between the sum of the squares of the first ten
//! natural numbers and the square of the sum is $3025 - 385 = 2640$.</p>
//! <p>Find the difference between the sum of the squares of the first one
//! hundred natural numbers and the square of the sum.</p>

const std = @import("std");
const expectEqual = std.testing.expectEqual;

pub fn sumSquareDifference(limit: u64) u64 {
    var sum_of_squares: u64 = 0;
    for (1..limit+1) |i| {
        sum_of_squares += i * i;
    }
    const sum = (1 + limit)*limit / 2;
    return sum * sum - sum_of_squares;
}

test sumSquareDifference {
    try expectEqual(2640, sumSquareDifference(10));
}
