module fixed.internal.uint128gen;

import fixed.uint128;

void inc128(ref uint128 x)
{
    ++x.lo;
    if (!x.lo)
        ++x.hi;
}

void dec128(ref uint128 x)
{
    if (!x.lo)
        --x.hi;
    --x.lo;
}

void not128(ref uint128 x)
{
    x.lo = ~x.lo;
    x.hi = ~x.hi;
}

void neg128(ref uint128 x)
{
    not128(x);
    inc128(x);
}

void and128(ref uint128 x, const ref uint128 y)
{
    x.lo &= y.lo;
    x.hi &= y.hi;
}

void or128(ref uint128 x, const ref uint128 y)
{
    x.lo |= y.lo;
    x.hi |= y.hi;
}

void xor128(ref uint128 x, const ref uint128 y)
{
    x.lo ^= y.lo;
    x.hi ^= y.hi;
}

void add128(ref uint128 x, const ref uint128 y)
{
    auto save = x.lo;
    x.lo += y.lo;
    x.hi += y.hi;
    if (save > x.lo)
        ++x.hi;
}

void sub128(ref uint128 x, const ref uint128 y)
{
    auto save = x.lo;
    x.lo -= y.lo;
    x.hi -= y.hi;
    if (save < x.lo)
        --x.hi;
}
