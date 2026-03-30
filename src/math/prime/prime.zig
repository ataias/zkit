const std = @import("std");

pub const Sieve = @import("Sieve.zig");

/// Trial division primality test.
/// Time: O(sqrt(n)). Memory: O(1).
pub fn isPrime(n: u64) bool {
    if (n < 2) return false;
    if (n == 2) return true;
    if (n % 2 == 0) return false;

    var i: u64 = 3;
    while (i * i <= n) : (i += 2) {
        if (n % i == 0) return false;
    }
    return true;
}

test isPrime {
    try std.testing.expect(!isPrime(0));
    try std.testing.expect(!isPrime(1));
    try std.testing.expect(isPrime(2));
    try std.testing.expect(isPrime(3));
    try std.testing.expect(!isPrime(4));
    try std.testing.expect(isPrime(5));
    try std.testing.expect(isPrime(97));
    try std.testing.expect(!isPrime(100));
}

/// For a given numeric type like u16, u32, u64, etc,
/// the max number of factors a number can have is based on the primorial p#
pub fn maxDistinctPrimeFactors(comptime T: type) comptime_int {
    const primes = [_]T{ 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59 };
    var product: T = 1;
    for (primes, 0..) |p, i| {
        if (@mulWithOverflow(product, p)[1] != 0) return i;
        product *= p;
    }
    return primes.len;
}

test {
    _ = Sieve;
}
