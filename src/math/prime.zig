const std = @import("std");
const StaticBitSet = std.StaticBitSet;
const DynamicBitSet = std.DynamicBitSet;
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

pub const Sieve = struct {
    bitSet: DynamicBitSet,
    limit: usize,

    pub fn init(allocator: Allocator, limit: usize) !Sieve {
        var bitSet = try DynamicBitSet.initFull(allocator, limit / 2);
        errdefer bitSet.deinit();

        var i: usize = 3;
        while (i * i < limit) : (i += 2) {
            if (bitSet.isSet(i / 2 - 1)) {
                var j = i * i;
                while (j < limit) : (j += 2 * i) {
                    bitSet.unset(j / 2 - 1);
                }
            }
        }
        return .{ .bitSet = bitSet, .limit = limit };
    }

    pub fn deinit(self: *Sieve) void {
        self.bitSet.deinit();
    }

    pub fn isPrime(self: *const Sieve, n: usize) bool {
        std.debug.assert(n < self.limit);
        return n >= 2 and (n == 2 or (n % 2 == 1 and self.bitSet.isSet(n / 2 - 1)));
    }
};

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

test Sieve {
    const allocator = std.testing.allocator;
    var s = try Sieve.init(allocator, 200);
    defer s.deinit();

    const expected_primes = [_]usize{
        2,   3,   5,   7,   11,  13,  17,  19,  23,  29,
        31,  37,  41,  43,  47,  53,  59,  61,  67,  71,
        73,  79,  83,  89,  97,  101, 103, 107, 109, 113,
        127, 131, 137, 139, 149, 151, 157, 163, 167, 173,
        179, 181, 191, 193, 197, 199,
    };
    for (expected_primes) |p| {
        try std.testing.expect(s.isPrime(p));
    }

    for (0..200) |n| {
        const expected = for (expected_primes) |p| {
            if (p == n) break true;
        } else false;
        try std.testing.expectEqual(expected, s.isPrime(n));
    }
}

test comptimeSieve {
    const checkPrime = comptimeSieve(200);

    const expected_primes = [_]usize{
        2,   3,   5,   7,   11,  13,  17,  19,  23,  29,
        31,  37,  41,  43,  47,  53,  59,  61,  67,  71,
        73,  79,  83,  89,  97,  101, 103, 107, 109, 113,
        127, 131, 137, 139, 149, 151, 157, 163, 167, 173,
        179, 181, 191, 193, 197, 199,
    };
    for (expected_primes) |p| {
        try std.testing.expect(checkPrime(p));
    }

    for (0..200) |n| {
        const expected = for (expected_primes) |p| {
            if (p == n) break true;
        } else false;
        try std.testing.expectEqual(expected, checkPrime(n));
    }
}
