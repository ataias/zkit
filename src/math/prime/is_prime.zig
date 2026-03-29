const std = @import("std");

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
