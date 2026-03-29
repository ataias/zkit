const std = @import("std");
const StaticBitSet = std.StaticBitSet;
const Allocator = std.mem.Allocator;

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

pub fn comptimeSieve(comptime limit: usize) *const fn(u64) bool {
    @setEvalBranchQuota(limit);
    const S = struct {
        const primeBitSet = blk: {
            var bitSet = StaticBitSet(limit / 2).initFull();

            // We only store odd numbers, as even numbers are not prime, with
            // the exception of 2.
            var i: usize = 3;
            while (i * i < limit) : (i += 2) {
                if (bitSet.isSet(i / 2 - 1)) {
                    var j = i * i;
                    while (j < limit) : (j += 2 * i) {
                        bitSet.unset(j / 2 - 1);
                    }
                }
            }
            break :blk bitSet;
        };
        fn isPrime(n: u64) bool {
            if (n > limit) @panic("n exceeds comptimeSieve limit");
            return n >= 2 and (n == 2 or (@rem(n, 2) == 1 and primeBitSet.isSet(n / 2 - 1)));
        }
    };
    return S.isPrime;
}

pub fn sieve(allocator: Allocator, limit: usize) ![]bool {
    const is_prime = try allocator.alloc(bool, limit);
    errdefer allocator.free(is_prime);

    @memset(is_prime, true);
    if (limit > 0) is_prime[0] = false;
    if (limit > 1) is_prime[1] = false;

    var i: usize = 2;
    while (i * i < limit) : (i += 1) {
        if (is_prime[i]) {
            var j = i * i;
            while (j < limit) : (j += i) {
                is_prime[j] = false;
            }
        }
    }
    return is_prime;
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

test sieve {
    const allocator = std.testing.allocator;
    const table = try sieve(allocator, 20);
    defer allocator.free(table);

    const expected_primes = [_]usize{ 2, 3, 5, 7, 11, 13, 17, 19 };
    for (expected_primes) |p| {
        try std.testing.expect(table[p]);
    }
    try std.testing.expect(!table[0]);
    try std.testing.expect(!table[1]);
    try std.testing.expect(!table[4]);
    try std.testing.expect(!table[9]);
}

test comptimeSieve {
    const checkPrime = comptimeSieve(200);

    const expected_primes = [_]usize{ 2, 3, 5, 7, 11, 13, 17, 19 };
    for (expected_primes) |p| {
        try std.testing.expect(checkPrime(p));
    }
    try std.testing.expect(!checkPrime(0));
    try std.testing.expect(!checkPrime(1));
    try std.testing.expect(!checkPrime(4));
    try std.testing.expect(!checkPrime(9));
}
