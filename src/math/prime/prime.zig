const std = @import("std");

pub const is_prime = @import("is_prime.zig");
pub const Sieve = @import("Sieve.zig");

test {
    _ = is_prime;
    _ = Sieve;
}
