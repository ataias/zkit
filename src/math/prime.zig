const std = @import("std");
const StaticBitSet = std.StaticBitSet;
const DynamicBitSet = std.DynamicBitSet;
const Allocator = std.mem.Allocator;

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

/// Sieve of Eratosthenes for prime checking.
/// Memory: O(limit) bits.
pub const Sieve = struct {
    bitSet: DynamicBitSet,
    limit: usize,

    /// Time: O(n * ln(ln(n))) where n = limit. Memory: O(n) bits.
    pub fn init(allocator: Allocator, limit: usize) !Sieve {
        // We store only the odd numbers, so in principle we need limit / 2 bits.
        const size = blk: {
            if (limit <= 1) {
                break :blk 0;
            }
            break :blk if (@rem(limit, 2) == 0) limit / 2 - 1 else limit / 2;
        };
        var bitSet = try DynamicBitSet.initFull(allocator, size);
        errdefer bitSet.deinit();
        mark(&bitSet, limit);
        return .{ .bitSet = bitSet, .limit = limit };
    }

    pub fn deinit(self: *Sieve) void {
        self.bitSet.deinit();
    }

    /// Time: O(1).
    pub fn isPrime(self: *const Sieve, n: usize) bool {
        std.debug.assert(n <= self.limit);
        return check(&self.bitSet, n);
    }

    /// Compile-time sieve. The returned function checks primality in O(1).
    /// Memory: O(limit) bits, embedded in the binary.
    pub fn comptime_(comptime limit: usize) *const fn(u64) SieveError!bool {
        @setEvalBranchQuota(limit);
        const S = struct {
            const primeBitSet = blk: {
                var bitSet = StaticBitSet(limit / 2).initFull();
                mark(&bitSet, limit);
                break :blk bitSet;
            };
            fn isPrime(n: u64) SieveError!bool {
                if (n > limit) {
                    return error.OutOfBand;
                }
                return check(&primeBitSet, @intCast(n));
            }
        };
        return S.isPrime;
    }

    // We only store odd numbers, as even numbers are not prime, with
    // the exception of 2.
    fn mark(bitSet: anytype, limit: usize) void {
        var i: usize = 3;
        while (i * i <= limit) : (i += 2) {
            if (bitSet.isSet(toBitIndex(i))) {
                var j = i * i;
                while (j <= limit) : (j += 2 * i) {
                    bitSet.unset(toBitIndex(j));
                }
            }
        }
    }

    fn check(bitSet: anytype, n: usize) bool {
        return n >= 2 and (n == 2 or (n % 2 == 1 and bitSet.isSet(toBitIndex(n))));
    }

    inline fn toBitIndex(prime: usize) usize {
        return prime / 2 - 1;
    }

    inline fn fromIndex(i: usize) usize {
        const prime = i * 2 + 3;
        return prime;
    }

    pub fn nextPrime(self: *const Sieve, n: usize) SieveError!usize {
        var iter = self.iterator();
        while (iter.next()) |value| {
            if (value > n) {
                return value;
            }
        }
        return error.OutOfBand;
    }

    pub fn prevPrime(self: *const Sieve, n: usize) SieveError!?usize {
        var iter = self.iterator();
        var previous: ?usize = null;
        while (iter.next()) |value| {
            if (value >= n) {
                return previous;
            }
            previous = value;
        }
        return error.OutOfBand;
    }

    pub fn count(self: *const Sieve) usize {
        if (self.limit <= 1) {
            return 0;
        }
        if (self.limit == 2) {
            return 1;
        }
        return 1 + self.bitSet.count();
    }

    pub const Iterator = struct {
        inner: DynamicBitSet.Iterator(.{}),
        limit: usize,
        yielded_two: bool = false,

        pub fn next(self: *Iterator) ?u64 {
            if (!self.yielded_two) {
                self.yielded_two = true;
                return 2;
            }
            const bit_index = self.inner.next() orelse return null;
            const prime = fromIndex(bit_index);
            if (prime > self.limit) return null;
            return prime;
        }
    };

    pub fn iterator(self: *const Sieve) Iterator {
        return .{ .inner = self.bitSet.iterator(.{}), .limit = self.limit };
    }

    pub const SieveError = error{
        OutOfBand,
    };
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

    const composites_at_limit = [_]usize{ 9, 25, 49, 121, 169 };
    for (composites_at_limit) |limit| {
        var sieve = try Sieve.init(allocator, limit);
        defer sieve.deinit();
        try std.testing.expect(!sieve.isPrime(limit));
    }
}

test "Sieve.Iterator" {
    const expected_primes = [_]u64{
        2,   3,   5,   7,   11,  13,  17,  19,  23,  29,
        31,  37,  41,  43,  47,  53,  59,  61,  67,  71,
        73,  79,  83,  89,  97,  101, 103, 107, 109, 113,
        127, 131, 137, 139, 149, 151, 157, 163, 167, 173,
        179, 181, 191, 193, 197, 199,
    };

    const allocator = std.testing.allocator;
    const limits = [_]u64{199, 200};
    for (limits) |limit| {
        var s = try Sieve.init(allocator, limit);
        defer s.deinit();

        var it = s.iterator();
        for (expected_primes) |expected| {
            try std.testing.expectEqual(expected, it.next());
        }
        try std.testing.expectEqual(null, it.next());
    }
}

test "Sieve.comptime_" {
    const sieveIsPrime = Sieve.comptime_(200);

    const expected_primes = [_]usize{
        2,   3,   5,   7,   11,  13,  17,  19,  23,  29,
        31,  37,  41,  43,  47,  53,  59,  61,  67,  71,
        73,  79,  83,  89,  97,  101, 103, 107, 109, 113,
        127, 131, 137, 139, 149, 151, 157, 163, 167, 173,
        179, 181, 191, 193, 197, 199,
    };
    for (expected_primes) |p| {
        try std.testing.expect(try sieveIsPrime(p));
    }

    for (0..200) |n| {
        const expected = for (expected_primes) |p| {
            if (p == n) break true;
        } else false;
        try std.testing.expectEqual(expected, sieveIsPrime(n));
    }
}

test "Sieve.count" {
    const allocator = std.testing.allocator;
    {
        var sieve = try Sieve.init(allocator, 0);
        defer sieve.deinit();
        try std.testing.expectEqual(0, sieve.count());
    }
    {
        var sieve = try Sieve.init(allocator, 1);
        defer sieve.deinit();
        try std.testing.expectEqual(0, sieve.count());
    }
    const expected_primes = [_]usize{
        2,   3,   5,   7,   11,  13,  17,  19,  23,  29,
        31,  37,  41,  43,  47,  53,  59,  61,  67,  71,
        73,  79,  83,  89,  97,  101, 103, 107, 109, 113,
        127, 131, 137, 139, 149, 151, 157, 163, 167, 173,
        179, 181, 191, 193, 197, 199,
    };
    for (0..expected_primes.len) |i| {
        var sieve = try Sieve.init(allocator, expected_primes[i]);
        defer sieve.deinit();
        try std.testing.expectEqual(i+1, sieve.count());
    }
    {
        var sieve = try Sieve.init(allocator, 4);
        defer sieve.deinit();
        try std.testing.expectEqual(2, sieve.count());
    }
    {
        var sieve = try Sieve.init(allocator, 200);
        defer sieve.deinit();
        try std.testing.expectEqual(expected_primes.len, sieve.count());
    }
}

test "Sieve.nextPrime" {
    const allocator = std.testing.allocator;
    var sieve = try Sieve.init(allocator, 200);
    defer sieve.deinit();
    const OutOfBand = Sieve.SieveError.OutOfBand;
    try std.testing.expectEqual(2, sieve.nextPrime(0));
    try std.testing.expectEqual(2, sieve.nextPrime(1));
    try std.testing.expectEqual(3, sieve.nextPrime(2));
    try std.testing.expectEqual(5, sieve.nextPrime(3));
    try std.testing.expectEqual(5, sieve.nextPrime(4));
    try std.testing.expectEqual(7, sieve.nextPrime(5));
    try std.testing.expectEqual(197, sieve.nextPrime(193));
    try std.testing.expectEqual(OutOfBand, sieve.nextPrime(199));
}

test "Sieve.prevPrime" {
    const allocator = std.testing.allocator;
    var sieve = try Sieve.init(allocator, 200);
    defer sieve.deinit();
    const OutOfBand = Sieve.SieveError.OutOfBand;
    try std.testing.expectEqual(OutOfBand, sieve.prevPrime(300));
    try std.testing.expectEqual(197, sieve.prevPrime(199));
    try std.testing.expectEqual(2, sieve.prevPrime(3));
    try std.testing.expectEqual(3, sieve.prevPrime(4));
    try std.testing.expectEqual(3, sieve.prevPrime(5));
    try std.testing.expectEqual(191, sieve.prevPrime(193));
    try std.testing.expectEqual(null, sieve.prevPrime(2));
    try std.testing.expectEqual(null, sieve.prevPrime(1));
    try std.testing.expectEqual(null, sieve.prevPrime(0));
}
