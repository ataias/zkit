//! Sieve of Eratosthenes for prime checking.
//! Memory: O(limit) bits.
const std = @import("std");
const StaticBitSet = std.StaticBitSet;
const DynamicBitSet = std.DynamicBitSet;
const Allocator = std.mem.Allocator;

bitSet: DynamicBitSet,
limit: usize,

/// Time: O(n * ln(ln(n))) where n = limit. Memory: O(n) bits.
pub fn init(allocator: Allocator, limit: usize) !@This() {
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

pub fn deinit(self: *@This()) void {
    self.bitSet.deinit();
}

/// Time: O(1).
pub fn isPrime(self: *const @This(), n: usize) bool {
    std.debug.assert(n <= self.limit);
    return check(&self.bitSet, n);
}

test isPrime {
    const allocator = std.testing.allocator;
    var s = try init(allocator, 200);
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
        var sieve = try init(allocator, limit);
        defer sieve.deinit();
        try std.testing.expect(!sieve.isPrime(limit));
    }
}

/// Compile-time sieve. The returned function checks primality in O(1).
/// Memory: O(limit) bits, embedded in the binary.
pub fn comptimeMakeIsPrime(comptime limit: usize) *const fn (u64) SieveError!bool {
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

test comptimeMakeIsPrime {
    const sieveIsPrime = comptimeMakeIsPrime(200);

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

pub fn nextPrime(self: *const @This(), n: usize) SieveError!usize {
    var iter = self.iterator(.{});
    while (iter.next()) |value| {
        if (value > n) {
            return value;
        }
    }
    return error.OutOfBand;
}

test nextPrime {
    const allocator = std.testing.allocator;
    var sieve = try init(allocator, 200);
    defer sieve.deinit();
    const OutOfBand = SieveError.OutOfBand;
    try std.testing.expectEqual(2, sieve.nextPrime(0));
    try std.testing.expectEqual(2, sieve.nextPrime(1));
    try std.testing.expectEqual(3, sieve.nextPrime(2));
    try std.testing.expectEqual(5, sieve.nextPrime(3));
    try std.testing.expectEqual(5, sieve.nextPrime(4));
    try std.testing.expectEqual(7, sieve.nextPrime(5));
    try std.testing.expectEqual(197, sieve.nextPrime(193));
    try std.testing.expectEqual(OutOfBand, sieve.nextPrime(199));
}

pub fn prevPrime(self: *const @This(), n: usize) SieveError!?usize {
    var iter = self.iterator(.{});
    var previous: ?usize = null;
    while (iter.next()) |value| {
        if (value >= n) {
            return previous;
        }
        previous = value;
    }
    return error.OutOfBand;
}

test prevPrime {
    const allocator = std.testing.allocator;
    var sieve = try init(allocator, 200);
    defer sieve.deinit();
    const OutOfBand = SieveError.OutOfBand;
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

pub fn count(self: *const @This()) usize {
    if (self.limit <= 1) {
        return 0;
    }
    if (self.limit == 2) {
        return 1;
    }
    return 1 + self.bitSet.count();
}

test count {
    const allocator = std.testing.allocator;
    {
        var sieve = try init(allocator, 0);
        defer sieve.deinit();
        try std.testing.expectEqual(0, sieve.count());
    }
    {
        var sieve = try init(allocator, 1);
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
        var sieve = try init(allocator, expected_primes[i]);
        defer sieve.deinit();
        try std.testing.expectEqual(i + 1, sieve.count());
    }
    {
        var sieve = try init(allocator, 4);
        defer sieve.deinit();
        try std.testing.expectEqual(2, sieve.count());
    }
    {
        var sieve = try init(allocator, 200);
        defer sieve.deinit();
        try std.testing.expectEqual(expected_primes.len, sieve.count());
    }
}

pub const Iterator = struct {
    inner: DynamicBitSet.Iterator(.{}),
    limit: usize,
    yielded_two: bool = false,
    options: Options,

    pub fn next(self: *Iterator) ?u64 {
        const start = self.options.start;
        const stop = self.options.stop;
        if (!self.yielded_two) {
            self.yielded_two = true;
            if (stop != null and stop.? < 2) {
                return null;
            }
            if (start == null or start.? <= 2) {
                return 2;
            }
        }
        var bit_index = self.inner.next() orelse return null;
        var prime = fromIndex(bit_index);
        while (start != null and prime < start.?) {
            bit_index = self.inner.next() orelse return null;
            prime = fromIndex(bit_index);
        }
        if (prime > self.limit or (stop != null and prime > stop.?)) return null;
        return prime;
    }

    pub const Options = struct {
        start: ?usize = null,
        stop: ?usize = null,
    };
};

pub fn iterator(self: *const @This(), options: Iterator.Options) Iterator {
    return .{
        .inner = self.bitSet.iterator(.{}),
        .limit = self.limit,
        .options = options,
    };
}

test iterator {
    const expected_primes = [_]u64{
        2,   3,   5,   7,   11,  13,  17,  19,  23,  29,
        31,  37,  41,  43,  47,  53,  59,  61,  67,  71,
        73,  79,  83,  89,  97,  101, 103, 107, 109, 113,
        127, 131, 137, 139, 149, 151, 157, 163, 167, 173,
        179, 181, 191, 193, 197, 199,
    };

    const allocator = std.testing.allocator;
    // Default options
    {
        const limits = [_]u64{ 199, 200 };
        for (limits) |limit| {
            var s = try init(allocator, limit);
            defer s.deinit();

            var it = s.iterator(.{});
            for (expected_primes) |expected| {
                try std.testing.expectEqual(expected, it.next());
            }
            try std.testing.expectEqual(null, it.next());
        }
    }
    // Ranges
    {
        var s = try init(allocator, 200);
        defer s.deinit();
        {
            var it = s.iterator(.{ .start = 80, .stop = 130 });
            const expected_range = [_]u64{ 83, 89, 97, 101, 103, 107, 109, 113, 127 };
            for (expected_range) |expected| {
                try std.testing.expectEqual(expected, it.next());
            }
            try std.testing.expectEqual(null, it.next());
        }
        {
            var it = s.iterator(.{ .stop = 1 });
            try std.testing.expectEqual(null, it.next());
        }
        {
            var it = s.iterator(.{ .stop = 2 });
            try std.testing.expectEqual(2, it.next());
            try std.testing.expectEqual(null, it.next());
        }
        {
            var it = s.iterator(.{ .start = 190 });
            const expected_range = [_]u64{ 191, 193, 197, 199 };
            for (expected_range) |expected| {
                try std.testing.expectEqual(expected, it.next());
            }
            try std.testing.expectEqual(null, it.next());
        }
    }
}

pub const SieveError = error{
    OutOfBand,
};

pub const PrimeFactor = struct {
    base: u64,
    exp: u64,
};

pub const PrimeFactorIterator = struct {
    n: u64,
    iter: Iterator,

    pub fn next(self: *PrimeFactorIterator) SieveError!?PrimeFactor {
        if (self.n <= 1) return null;
        const p = self.smallestFactor() orelse {
            if (self.n > 1) {
                return SieveError.OutOfBand;
            }
            return null;
        };
        var exp: u64 = 0;
        while (self.n % p == 0) {
            self.n /= p;
            exp += 1;
        }
        return .{ .base = p, .exp = exp };
    }

    fn smallestFactor(self: *PrimeFactorIterator) ?u64 {
        while (self.iter.next()) |value| {
            if (@rem(self.n, value) == 0) {
                return value;
            }
        }
        return null;
    }
};

pub fn primeFactors(self: *const @This(), n: u64) PrimeFactorIterator {
    const iter = self.iterator(.{});
    return .{ .n = n, .iter = iter };
}

test primeFactors {
    // const expected_primes = [_]u64{
    //     2,   3,   5,   7,   11,  13,  17,  19,  23,  29,
    //     31,  37,  41,  43,  47,  53,  59,  61,  67,  71,
    //     73,  79,  83,  89,  97,  101, 103, 107, 109, 113,
    //     127, 131, 137, 139, 149, 151, 157, 163, 167, 173,
    //     179, 181, 191, 193, 197, 199,
    // };

    const allocator = std.testing.allocator;
    var s = try init(allocator, 200);
    defer s.deinit();

    {
        const n = 3 * 5 * 7;
        var it = s.primeFactors(n);
        try std.testing.expectEqual(PrimeFactor{.base = 3, .exp = 1}, it.next());
        try std.testing.expectEqual(PrimeFactor{.base = 5, .exp = 1}, it.next());
        try std.testing.expectEqual(PrimeFactor{.base = 7, .exp = 1}, it.next());
        try std.testing.expectEqual(null, it.next());
    }

    {
        const n = 3 * 3 * 5 * 5 * 5 * 199 * 199 * 199 * 199;
        var it = s.primeFactors(n);
        try std.testing.expectEqual(PrimeFactor{.base = 3, .exp = 2}, it.next());
        try std.testing.expectEqual(PrimeFactor{.base = 5, .exp = 3}, it.next());
        try std.testing.expectEqual(PrimeFactor{.base = 199, .exp = 4}, it.next());
        try std.testing.expectEqual(null, it.next());
    }

    {
        const n = 294887; // prime number, outside our range
        var it = s.primeFactors(n);
        try std.testing.expectEqual(SieveError.OutOfBand, it.next());
        try std.testing.expectEqual(SieveError.OutOfBand, it.next());
    }

    {
        // works with a bigger sieve
        var superSieve = try init(allocator, 500_000);
        defer superSieve.deinit();
        const n = 294887; // prime number, outside our range
        var it = superSieve.primeFactors(n);
        try std.testing.expectEqual(PrimeFactor{.base = 294887, .exp = 1}, it.next());
        try std.testing.expectEqual(null, it.next());
    }
}

test fuzzPrimeFactors {
    try std.testing.fuzz({}, fuzzPrimeFactors, .{});
}

fn fuzzPrimeFactors(context: void, smith: *std.testing.Smith) !void {
    _ = context;
    const limit = 10_000;
    const allocator = std.testing.allocator;
    var s = try init(allocator, limit);
    defer s.deinit();

    const n = smith.valueRangeAtMost(u64, 2, 10_000);
    errdefer std.debug.print("failing n = {}\n", .{n});
    var it = s.primeFactors(n);

    var product: u64 = 1;
    while (try it.next()) |factor| {
        product = product * std.math.pow(u64, factor.base, factor.exp);
        try std.testing.expect(factor.base <= limit);
        try std.testing.expect(factor.exp >= 1);
    }

    try std.testing.expectEqual(n, product);
}
