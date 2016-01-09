module fixed;

import core.bitop;
import std.traits;

version(unittest)
{
    alias uint128 = Fixed!(128, false);
    alias uint256 = Fixed!(256, false);
    alias uint512 = Fixed!(512, false);

    alias int128 = Fixed!(128, true);
    alias int256 = Fixed!(256, true);
    alias int512 = Fixed!(512, true);

}

struct Fixed(int bits, bool signed)
{
private:
    alias ThisType = Fixed!(bits, signed);
    alias LoType = MakeFixed!(bits / 2, false);
    alias HiType = MakeFixed!(bits / 2, signed);

    static assert (isPowerOfTwo(bits), "Bit count must be a power of two");
    static assert (bits >= 128, "Use " ~ MakeFixed!(bits, signed).stringof ~ " instead of " ~ ThisType.stringof);

    version(LittleEndian)
    {
        LoType lo;
        HiType hi;
    }
    else
    {
        HiType hi;
        LoType lo;
    }

    this(H, L)(auto const ref H h, auto const ref L l) if (canAssign!(LoType, L) && canAssign!(HiType, H))
    {
        this.hi = h;
        this.lo = l;
    }

   

    bool fromHex(C)(const(C)[] s) if (isSomeChar!C)
    {
        bool anyDigit, prefix = true;
        ThisType ret;
        int width;
        foreach (c; s)
        {
            if (c == '_')
                continue;
            else if (c == '0' && prefix)
            {
                anyDigit = true;
                continue;
            }
            else if (c >= '0' && c <= '9')
            {
                anyDigit = true;
                prefix = false;
                if (width >= bits)
                    return false;
                width += 4;
                ret <<= 4;
                ret |= (c - '0');
            }
            else if (c >= 'A' && c <= 'F')
            {
                anyDigit = true;
                prefix = false;
                if (width >= bits)
                    return false;
                width += 4;
                ret <<= 4;
                ret |= (c - 'A' + 10);
            }
            else if (c >= 'a' && c <= 'f')
            {
                anyDigit = true;
                prefix = false;
                if (width >= bits)
                    return false;
                width += 4;
                ret <<= 4;
                ret |= (c - 'a' + 10);
            }
            else
                return false;
        }
        if (anyDigit)
            this = ret;
        return anyDigit;
    }

    bool fromDec(C)(const(C)[] s) if (isSomeChar!C)
    {
        bool anyDigit, prefix = true;
        ThisType ret;
        foreach (c; s)
        {
            if (c == '_')
                continue;
            else if (c == '0' && prefix)
            {
                anyDigit = true;
                continue;
            }
            else if (c >= '0' && c <= '9')
            {
                anyDigit = true;
                prefix = false;
                auto retx = mul(ret, 10U);
                retx += c - '0';
                if (retx > ThisType.max)
                    return false;
                ret = cast(ThisType)retx;
            }
            else
                return false;
        }
        if (anyDigit)
            this = ret;
        return anyDigit;
    }

    void toHex(C)(scope void delegate(const(C)[]) sink, int width, const bool zeroFill, const bool upperCase) const if (isSomeChar!C)
    {
        C[16] hexDigits = "0123456789abcdef";
        C[16] HEXDigits = "0123456789ABCDEF";
        C[bits / 4] buffer;
        size_t i = buffer.length;
        if (!this)
            buffer[--i] = '0';
        else
        {
            Unsigned!ThisType x = this;
            while(x)
            {
                auto j = cast(int)(x) & 0xf;
                x >>= 4;
                buffer[--i] = upperCase ? HEXDigits[j] : hexDigits[j];
            }
        }
        
        int w = width < 0 ? -width : width;
        w -= (buffer.length - i);

        if (width > 0 && w > 0)
        {
            while (w--)
                sink(zeroFill ? "0" : " ");
        }

        sink(buffer[i .. $]);

        if (width < 0 && w > 0)
        {
            while(w--)
                sink(" ");
        }
    }

    void toDec(C)(scope void delegate(const(C)[]) sink, int width, const bool zeroFill, const bool forceSign, const bool spaceAlign) const if (isSomeChar!C)
    {
        C[bits / 3 + 1] buffer;
        size_t i = buffer.length;
        if (!this)
            buffer[--i] = '0';
        else
        {
            static if (isAnySigned!ThisType)
                Unsigned!ThisType x = this < 0 ? -this : this;
            else
                Unsigned!ThisType x = this;
            Unsigned!ThisType r;
            while(x)
            {
                x = divmod(x, 10U, r);
                buffer[--i] = cast(C)('0' + cast(int)r);
            }
        }

        int w = width < 0 ? -width : width;
        w -= (buffer.length - i);
        
        bool outputSign = (isAnySigned!ThisType && this < 0) || forceSign || spaceAlign;

        if (outputSign)
            --w;

        if (!zeroFill && width > 0 && w > 0)
        {
            while (w--)
                sink(" ");
        }

        if (outputSign)
        {
            if (this < 0)
                sink("-");
            else if (forceSign)
                sink("+");
            else
                sink(" ");
        }

        if (zeroFill && width > 0 && w > 0)
        {
            while (w--)
                sink("0");
        }

        sink(buffer[i .. $]);

        if (width < 0 && w > 0)
        {
            while(w--)
                sink(" ");
        }
    }

    import std.format : FormatSpec;

    void toString(C)(scope void delegate(const(C)[]) sink, ref FormatSpec!C f) const if (isSomeChar!C)
    {
        import std.format : FormatException;
        bool isHex = f.spec == 'x' || f.spec == 'X';
        if (isHex)
            toHex(sink, f.width, f.flZero, f.spec == 'X');
        else if (f.spec == 'd' || f.spec == 'i' || f.spec == 'u' || f.spec == 's')
        {
            static if (isAnySigned!ThisType)
            {
                if (f.spec == 'u')
                    Unsigned!ThisType t = this;
                else
                    alias t = this;
            }
            else
                alias t = this;
            toDec(sink, f.width, f.flZero, f.flDash, f.flSpace);
        }
        else
            throw new FormatException("Unsupported format specifier: %" ~ f.spec);
    }

    void toString(C)(scope void delegate(const (C)[]) sink, string formatString) const if (isSomeChar!C)
    {
        auto f = FormatSpec!char(formatString);
        f.writeUpToNextSpec(sink);
        toString(sink, f);
    }

public:
    enum max = ThisType(HiType.max, LoType.max);
    enum min = ThisType(HiType.min, LoType.max);

    this(C)(const(C)[] s) if (isSomeChar!C)
    {
        opAssign(s);     
    }

    this(T)(auto const ref T x) if (canAssign!(ThisType, T))
    {
        static if (bitWidth!T == bitWidth!ThisType)
        {
            this.lo = x.lo;
            this.hi = x.hi;
        }
        else static if (isAnyUnsigned!ThisType || isAnyUnsigned!T)
        {
            this.lo = x;
        }
        else
        {
            this.lo = x;
            if (x < 0)
                this.hi = -1;
        }
    }

    unittest
    {
        assert(to!string(uint128(10)) == "10");
        assert(to!string(int128(-10)) == "-10");
    }

    auto ref opAssign(C)(const(C)[] s) if (isSomeChar!C)
    {
        import std.conv : ConvException;
        bool isNegative = s.length > 0 && s[0] == '-';
        bool isPositive = s.length > 0 && s[0] == '+';
        size_t i = isNegative || isPositive ? 1 : 0;
        bool isHex = !signed && s.length > 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X');
        if (isHex)
        {
            if (!fromHex(s[i + 2 .. $]))
                throw new ConvException("Invalid hexadecimal format");
        }
        else
        {
            static if (isAnyUnsigned!ThisType)
            {
                if (!fromDec(s[i .. $]))
                    throw new ConvException("Invalid decimal format");
            }
            else
            {
                Unsigned!(ThisType) u;
                if (!u.fromDec(s[i .. $]))
                    throw new ConvException("Invalid decimal format");
                this = u;
            }

            if (isNegative)
                this = -this;
        }
    }

    auto ref opAssign(T)(auto const ref T x) if (canAssign!(ThisType, T))
    {
        static if (bitWidth!T == bitWidth!ThisType)
        {
            this.lo = x.lo;
            this.hi = x.hi;
        }
        else static if (isAnyUnsigned!ThisType || isAnyUnsigned!T)
        {
            this.hi = HiType.init;
            this.lo = x;
        }
        else
        {
            this.lo = x;
            this.hi = x < 0 ? -1 : HiType.init;
        }
        return this;
    }

    auto opUnary(string op : "+")() const
    {
        return this;
    }

    auto opUnary(string op : "~")() const
    {
        return ThisType(~this.hi, ~this.lo);
    }

    auto ref opUnary(string op: "++")()
    {
        ++this.lo;
        if (!this.lo)
            ++this.hi;
        return this;
    }

    auto ref opUnary(string op: "--")()
    {
        if (!this.lo)
            --this.hi;
        --this.lo;
        return this;
    }

    auto opUnary(string op: "-")() const
    {
        return ++(~this);
    }

    auto ref opOpAssign(string op : "&", T)(auto const ref T x) if (canAssign!(ThisType, T))
    {
        static if (bitWidth!T == bitWidth!ThisType)
        {
            this.lo &= x.lo;
            this.hi &= x.hi;
        }
        else
        {
            this.lo &= x;
            this.hi = HiType.init;
        }
        return this;
    }

    auto opBinary(string op : "&", T)(auto const ref T x) const if (canAssign!(ThisType, T))
    {
        static if (bitWidth!T == bitWidth!ThisType)
            return ThisType(this.hi & x.hi, this.lo & x.lo);
        else
            return ThisType(HiType.init, this.lo & x);
    }

    auto opBinaryRight(string op : "&", T)(auto const ref T x) const if (canAssign!(ThisType, T))
    {
        static if (bitWidth!T == bitWidth!ThisType)
            return ThisType(this.hi & x.hi, this.lo & x.lo);
        else
            return ThisType(HiType.init, this.lo & x);
    }


    auto ref opOpAssign(string op : "|", T)(auto const ref T x) if (canAssign!(ThisType, T))
    {
        static if (bitWidth!T == bitWidth!ThisType)
        {
            this.lo |= x.lo;
            this.hi |= x.hi;
        }
        else
            this.lo |= x;
        return this;
    }

    auto opBinary(string op : "|", T)(auto const ref T x) const if (canAssign!(ThisType, T))
    {
        static if (bitWidth!T == bitWidth!ThisType)
            return ThisType(this.hi | x.hi, this.lo | x.lo);
        else
            return ThisType(this.hi, this.lo | x);
    }

    auto opBinaryRight(string op : "|", T)(auto const ref T x) const if (canAssign!(ThisType, T))
    {
        static if (bitWidth!T == bitWidth!ThisType)
            return ThisType(this.hi | x.hi, this.lo | x.lo);
        else
            return ThisType(this.hi, this.lo | x);
    }

    auto ref opOpAssign(string op : "^", T)(auto const ref T x) if (canAssign!(ThisType, T))
    {
        static if (bitWidth!T == bitWidth!ThisType)
        {
            this.lo ^= x.lo;
            this.hi ^= x.hi;
        }
        else
            this.lo ^= x;
        return this;
    }

    auto opBinary(string op : "^", T)(auto const ref T x) const if (canAssign!(ThisType, T))
    {
        static if (bitWidth!T == bitWidth!ThisType)
            return ThisType(this.hi ^ x.hi, this.lo ^ x.lo);
        else
            return ThisType(this.hi, this.lo ^ x);
    }

    auto opBinaryRight(string op : "^", T)(auto const ref T x) const if (canAssign!(ThisType, T))
    {
        static if (bitWidth!T == bitWidth!ThisType)
            return ThisType(this.hi ^ x.hi, this.lo ^ x.lo);
        else
            return ThisType(this.hi, this.lo ^ x);
    }

    ref ThisType opOpAssign(string op : "+", T)(auto const ref T x) if (canAssign!(ThisType, T))
    {
        static if (isAnySigned!T)
        {
            if (x < 0)
                return this -= -x;
        }

        static if (bitWidth!T == bitWidth!ThisType)
        {
            auto save = this.lo;
            this.lo += x.lo;
            this.hi += x.hi;
            if (save > this.lo)
                ++this.hi;
        }
        else
        {
            auto save = this.lo;
            this.lo += x;
            if (save > this.lo)
                ++this.hi;     
        }
        return this;
    }

    auto opBinary(string op : "+", T)(auto const ref T x) const if (canAssign!(ThisType, T))
    {
        static if (isAnyUnsigned!ThisType || isAnySigned!T)
            alias R = Signed!ThisType;
        else
            alias R = ThisType;
        R ret = this;
        ret += x;
        return ret;
    }

    auto opBinaryRight(string op : "+", T)(auto const ref T x) const if (canAssign!(ThisType, T))
    {
        static if (isUnigned!ThisType || isAnySigned!T)
            alias R = Signed!ThisType;
        else
            alias R = ThisType;
        R ret = this;
        ret += x;
        return ret;
    }

    ref ThisType opOpAssign(string op : "-", T)(auto const ref T x) if (canAssign!(ThisType, T))
    {
        static if (isAnySigned!T)
        {
            if (x < 0)
                return this += -x;
        }

        static if (bitWidth!T == bitWidth!ThisType)
        {
            auto save = this.lo;
            this.lo -= x.lo;
            this.hi -= x.hi;
            if (save < this.lo)
                --this.hi;
        }
        else
        {
            auto save = this.lo;
            this.lo -= x;
            if (save < this.lo)
                --this.hi;     
        }
        return this;
    }

    auto opBinary(string op : "-", T)(auto const ref T x) const if (canAssign!(ThisType, T))
    {
        static if (isAnyUnsigned!ThisType || isAnySigned!T)
            alias R = Signed!ThisType;
        else
            alias R = ThisType;
        R ret = this;
        ret -= x;
        return ret;
    }

    auto opBinaryRight(string op : "-", T)(auto const ref T x) const if (canAssign!(ThisType, T))
    {
        static if (isUnigned!ThisType || isAnySigned!T)
            alias R = Signed!ThisType;
        else
            alias R = ThisType;
        R ret = T(x);
        ret -= this;
        return ret;
    }

    auto ref opOpAssign(string op : "*", T)(auto const ref T x) if (canAssign!(ThisType, T))
    {
        static if (isAnySigned!ThisType)
        {
            bool sgn = this < 0;
            Unsigned!ThisType t = (sgn ? -this : this);
        }
        else
            alias t = this;

        static if (isAnySigned!T)
        {
            bool sgnx = x < 0;
            Unsigned!T u = (sgnx ? -x : x);
        }
        else 
        {
            alias u = x;
            bool sgnx = false;
        }

        static if (bitWidth!ThisType == bitWidth!T)
        {
            Unsigned!ThisType ret = mul(t.lo, u.lo);
            ret.hi += t.hi * u.lo;
            ret.hi += t.lo * u.hi;
        }
        else
        {
            Unsigned!ThisType ret = mul(t.lo, u);
            ret.hi += t.hi * u;
        }

        static if (isAnyUnsigned!ThisType)
            return this = ret;
        else
            return this = (sgn == sgnx ? ret : -ret);

    }

    auto opBinary(string op : "*", T)(auto const ref T x) const if (canAssign!(ThisType, T))
    {
        static if (isAnyUnsigned!ThisType || isAnySigned!T)
            alias R = Signed!ThisType;
        else
            alias R = ThisType;
        R ret = this;
        ret *= x;
        return ret;
    }

    auto opBinaryRight(string op : "*", T)(auto const ref T x) const if (canAssign!(ThisType, T))
    {
        static if (isUnigned!ThisType || isAnySigned!T)
            alias R = Signed!ThisType;
        else
            alias R = ThisType;
        R ret = this;
        ret *= x;
        return ret;
    }

    auto ref opOpAssign(string op : "/", T)(auto const ref T x) if (canAssign!(ThisType, T))
    {
        static if (isAnySigned!ThisType)
        {
            bool sgn = this < 0;
            Unsigned!ThisType t = (sgn ? -this : this);
        }
        else
            alias t = this;

        static if (isAnySigned!T)
        {
            bool sgnx = x < 0;
            Unsigned!T u = (sgnx ? -x : x);
        }
        else 
        {
            alias u = x;
            bool sgnx = false;
        }

        Unsigned!ThisType ret = div(t, u);

        static if (isAnyUnsigned!ThisType)
            return this = ret;
        else
            return this = (sgn == sgnx ? ret : -ret);

    }

    auto opBinary(string op : "/", T)(auto const ref T x) const if (canAssign!(ThisType, T))
    {
        static if (isAnyUnsigned!ThisType || isAnySigned!T)
            alias R = Signed!ThisType;
        else
            alias R = ThisType;
        R ret = this;
        ret /= x;
        return ret;
    }

    auto opBinaryRight(string op : "/", T)(auto const ref T x) const if (canAssign!(ThisType, T))
    {
        static if (isAnyUnsigned!ThisType || isAnySigned!T)
            alias R = Signed!ThisType;
        else
            alias R = ThisType;
        R ret = ThisType(x);
        ret /= this;
        return ret;
    }


    auto ref opOpAssign(string op : "%", T)(auto const ref T x) if (canAssign!(ThisType, T))
    {
        static if (isAnySigned!ThisType)
        {
            bool sgn = this < 0;
            Unsigned!ThisType t = (sgn ? -this : this);
        }
        else
            alias t = this;

        static if (isAnySigned!T)
        {
            bool sgnx = x < 0;
            Unsigned!T u = (sgnx ? -x : x);
        }
        else 
        {
            alias u = x;
            bool sgnx = false;
        }

        Unsigned!ThisType ret = mod(t, u);

        static if (isAnyUnsigned!ThisType)
            return this = ret;
        else
            return this = (sgn == sgnx ? ret : -ret);

    }

    auto opBinary(string op : "%", T)(auto const ref T x) const if (canAssign!(ThisType, T))
    {
        static if (isAnyUnsigned!ThisType || isAnySigned!T)
            alias R = Signed!ThisType;
        else
            alias R = ThisType;
        R ret = this;
        ret %= x;
        return ret;
    }

    auto opBinaryRight(string op : "%", T)(auto const ref T x) const if (canAssign!(ThisType, T))
    {
        static if (isAnyUnsigned!ThisType || isAnySigned!T)
            alias R = Signed!ThisType;
        else
            alias R = ThisType;
        R ret = ThisType(x);
        ret %= this;
        return ret;
    }

    auto ref opOpAssign(string op : "<<", T: int)(auto const ref T x)
    {
        auto shift = x & (bitWidth!ThisType - 1);
        if (shift >= bitWidth!LoType)
        {
            this.hi = this.lo << (shift - bitWidth!LoType);
            this.lo = LoType.init;
        }
        else if (shift > 0)
        {
            this.hi = (this.hi << shift) | (this.lo >> (bitWidth!LoType - shift));
            this.lo <<= shift;
        }
        return this;
    }

    auto ref opOpAssign(string op : ">>>", T: int)(auto const ref T x)
    {
        auto shift = x & (bitWidth!ThisType - 1);
        if (shift >= bitWidth!LoType)
        {
            this.lo = this.hi >>> (shift - bitWidth!LoType);
            this.hi = LoType.init;
        }
        else if (shift > 0)
        {
            this.lo = (this.lo >>> shift) | (this.hi << (bitWidth!LoType - shift));
            this.hi >>>= shift;
        }
        return this;
    }

    auto ref opOpAssign(string op : ">>", T: int)(auto const ref T x)
    {
        auto shift = x & (bitWidth!ThisType - 1);
        if (shift >= bitWidth!LoType)
        {
            this.lo = this.hi >> (shift - bitWidth!LoType);
            static if (isAnySigned!ThisType)
                this.hi = this.hi < 0 ? -1 : LoType.init;
            else
                this.hi = LoType.init;
        }
        else if (shift > 0)
        {
            this.lo = (this.lo >> shift) | (this.hi << (bitWidth!LoType - shift));
            this.hi >>= shift;
        }
        return this;
    }

    auto opBinary(string op : ">>", T : int)(auto const ref T x) const
    {
       return ThisType(this) >>= x;
    }

    auto opBinary(string op : ">>>", T : int)(auto const ref T x) const
    {
        return ThisType(this) >>>= x;
    }

    auto opBinary(string op : "<<", T : int)(auto const ref T x) const
    {
        return ThisType(this) <<= x;
    }

    auto ref opOpAssign(string op : "^^", T)(auto const ref T x) if (canAssign!(ThisType, T))
    {
        static if (isAnySigned!T)
        {
            if (x < 0)
                this /= 0;
        }
        if (x == 0)
            return this = 1;
        else if (x == 1)
            return this;
        else if (x == 2)
            return this *= this;
        T p = x;
        ThisType v = this;
        this = 1;
        while (p)
        {
            if (p & 1)
                this *= v;
            v *= v;
            p >>= 1;
        }
        return this;
    }

    auto opBinary(string op : "^^", T)(auto const ref T x) if (canAssign!(ThisType, T))
    {
        ThisType ret = this;
        return ret ^^= x;
    }

    bool opEquals(T)(auto const ref T x) const if (isAnyIntegral!T)
    {
        static if (bitWidth!T == bitWidth!ThisType)
            return (this.lo == x.lo && this.hi == x.hi);
        else static if (bitWidth!T < bitWidth!ThisType)
            return !this.hi && this.lo == x;
        else
            return !x.hi && x.lo == this;
    }

    int opCmp(T)(auto const ref T x) const if (isAnyIntegral!T)
    {
        static if (isAnySigned!ThisType && !isAnySigned!T)
        {
            if (this.hi < 0)
                return -1;
        }

        static if (!isAnySigned!ThisType && isAnySigned!T)
        {
            static if (isFixed!T)
            {
                if (x.hi < 0)
                    return 1;
            }
            else
            {
                if (x < 0)
                    return 1;
            }
        }

        static if (bitWidth!T == bitWidth!ThisType)
        {
            if (this.hi > x.hi)
                return 1;
            if (this.hi < x.hi)
                return -1;
            if (this.lo > x.lo)
                return 1;
            if (this.lo < x.lo)
                return -1;
            return 0;
        }
        else static if (bitWidth!T < bitWidth!ThisType)
        {
            if (this.hi < 0)
                return -1;
            else if (this.hi > 0)
                return 1;
            if (this.lo > x)
                return 1;
            if (this.lo < x)
                return -1;
            return 0;
        }
        else
        {
            if (x.hi)
                return 1;
            if (this > x.lo)
                return 1;
            if (this < x.lo)
                return -1;
            return 0;
        }
        
    }

    bool opCast(T)() const if (is(T == bool))
    {
        return (this.lo | this.hi) != 0;
    }

    T opCast(T)() const if (isAnyIntegral!T || isSomeChar!T)
    {
        static if (is(T == ThisType))
            return this;
        else static if (bitWidth!T >= bitWidth!ThisType)
            return T(this);
        else
            return cast(T)(this.lo);
    }

    size_t toHash()
    {
        static if (bits == 128)
        {
            static if (bitWidth!size_t == 64)
                return this.lo ^ this.hi;
            else
                return cast(uint)(this.lo >> 32) ^
                       cast(uint)(this.hi >> 32) ^
                       cast(uint)(this.lo) ^
                       cast(uint)(this.hi);
        }
        else
        {
            return this.lo.toHash() ^ this.hi.toHash();
        }
    }

    T opCast(T)() if (isFloatingPoint!T)
    {
        return cast(T)(this.hi) * cast(T)(HiType.max) + cast(T)(this.lo);
    }
}

T to(T, S)(auto const ref S x) if (isFixed!S && (isIntegralBuiltIn!T || is(T == bool)))
{
    return cast(T)x;
}

T to(T, S)(auto const ref S x) if (isFixed!S && (isFloatingPoint!T))
{
    return cast(T)x;
}

T to(T, S)(auto const ref S x) if (isFixed!T && isFixed!S)
{
    static if (bitWidth!T == bitWidth!S)
        return x;
    else static if (bitWidth!T < bitWidth!S)
        return cast(T)x;
    else
        return T(x);
}


T to(T, S)(auto const ref S x) if (isFixed!S && isSomeString!T)
{
    alias C = Unqual!(typeof(T.init[0]));

    C[bitWidth!S / 3 + 2] buffer;
    size_t bufIndex;

    void localSink(const(C)[] s)
    {
        buffer[bufIndex .. bufIndex + s.length] = s;
        bufIndex += s.length;
    }
    
    x.toDec(&localSink, 0, false, false, false);

    
    return cast(T)(buffer[0 .. bufIndex].dup);
}

template isFixed(T : Fixed!(bits, signed), int bits, bool signed)
{
    enum isFixed = true;
}

template isFixed(T)
{
    enum isFixed = false;
}

template isUnsignedBuiltIn(T)
{
    enum isUnsignedBuiltIn = is(T == ubyte) || is(T == ushort) || is(T == uint) || is(T == ulong);
}

template isSignedBuiltIn(T)
{
    enum isSignedBuiltIn = is(T == byte) || is(T == short) || is(T == int) || is(T == long);
}

template isUnsignedFixed(T : Fixed!(bits, signed), int bits, bool signed)
{
    enum isUnsignedFixed = !signed;
}

template isSignedFixed(T : Fixed!(bits, signed), int bits, bool signed)
{
    enum isSignedFixed = signed;
}

template isUnsignedFixed(T)
{
    enum isUnsignedFixed = false;
}

template isSignedFixed(T)
{
    enum isSignedFixed = false;
}

template isAnyUnsigned(T)
{
    enum isAnyUnsigned = isUnsignedBuiltIn!T || isUnsignedFixed!T;
}

template isAnySigned(T)
{
    enum isAnySigned = isSignedBuiltIn!T || isSignedFixed!T;
}

template isIntegralBuiltIn(T)
{
    enum isIntegralBuiltIn = isSignedBuiltIn!T || isUnsignedBuiltIn!T;
}

template isAnyIntegral(T)
{
    enum isAnyIntegral = isAnySigned!T || isAnyUnsigned!T;
}

template bitWidth(T) if (isAnyIntegral!T || (is(T == char) || is(T == wchar) || is(T == dchar)))
{
    enum bitWidth = T.sizeof * 8;
}

template canAssign(T, U) if (isAnyIntegral!T && isAnyIntegral!U)
{
    enum canAssign = bitWidth!U <= bitWidth!T;
}

template canAssign(T, U) if (!isAnyIntegral!T || !isAnyIntegral!U)
{
    enum canAssign = false;
}

template Unsigned(T) if (isAnyIntegral!T)
{
    alias Unsigned = MakeFixed!(bitWidth!T, false);
}

template Signed(T) if (isAnyIntegral!T)
{
    alias Signed = MakeFixed!(bitWidth!T, true);
}

T abs(T)(auto const ref T x) if (isFixed!T)
{
    return x < 0 ? -x : x;
}

T pow(T)(auto const ref T x, auto const ref U y) if (isFixed!T && isAnyIntegral!U)
{
    return x ^^ y;
}

import std.ascii : LetterCase;

auto toChars(ubyte radix = 10, C = char, LetterCase letterCase = LetterCase.lower, T)(T value) if (isFixed!(Unqual!T) && isSomeChar!C)
{
    alias UT = Unqual!T;
    alias UC = Unqual!C;
    enum isP2 = isPowerOfTwo(radix);
    enum baseChar = letterCase == LetterCase.lower ? 'a' : 'A';
    struct Result
    {
        static if (isPowerOfTwo(radix))
        {
            UT value;
        }
        else
        {
            UC[bitwidth!UT / 8 * 6] buffer;
            size_t bufferStart = buffer.length;
        }

        this(UT value)
        {
            static if (!isP2)
            {
                if (value == 0)
                {
                    buffer[$ - 1] = "0";
                    --bufferStart;
                }
                else
                {
                    U remainder;
                    while (value)
                    {
                        value = divmod(value, radix, remainder);
                        static if (radix <= 10)
                        {
                            buffer[bufferStart--] = cast(C)('0' + cast(int)(remainder));
                        }
                        else
                        {
                            if (remainder < 10)
                                buffer[bufferStart--] = cast(C)('0' + cast(int)(remainder));
                            else
                                buffer[bufferStart--] = cast(C)(baseChar + cast(int)(remainder) - 10);
                        }
                    }
                }
            }
            else
            {

            }
        }

        
    }

    return Result(value);
}

private:

template MakeFixed(uint bits, bool signed)
{
    static assert (isPowerOfTwo(bits), "Bit count must be a power of two");
    static assert (bits >= 8, "Bit count must be greater or equal to 8");
    static if (signed)
    {
        static if (bits == 8)
            alias MakeFixed = byte;
        else static if (bits == 16)
            alias MakeFixed = short;
        else static if (bits == 32)
            alias MakeFixed = int;
        else static if (bits == 64)
            alias MakeFixed = long;
        else
            alias MakeFixed = Fixed!(bits, true);
    }
    else
    {
        static if (bits == 8)
            alias MakeFixed = ubyte;
        else static if (bits == 16)
            alias MakeFixed = ushort;
        else static if (bits == 32)
            alias MakeFixed = uint;
        else static if (bits == 64)
            alias MakeFixed = ulong;
        else
            alias MakeFixed = Fixed!(bits, false);
    }
}

bool isPowerOfTwo(T)(auto const ref T x) if (isAnyIntegral!T)
{
    return (x & (x - 1)) == 0;
}

auto mul(T, U)(auto const ref T x, auto const ref U y) if (is(T == ubyte) && (is(U == ubyte)))
{
    return cast(ushort)x * y;
}

auto mul(T, U)(auto const ref T x, auto const ref U y) if (is(T == ushort) && (is(U == ubyte) || is(U == ushort)))
{
    return cast(uint)x * y;
}

auto mul(T, U)(auto const ref T x, auto const ref U y) if (is(T == uint) && (is(U == ubyte) || is(U == ushort) || is(U == uint)))
{
    return cast(ulong)x * y;
}

auto mul(T, U)(auto const ref T x, auto const ref U y) if (is(T == ulong) && (is(U == ulong)))
{
    // 00 00 x1 x0 *
    // 00 00 y1 y0
    //-------------
    //       x0*y0
    //    x1*y0
    //    x0*y1
    // x1*y1

    if (x == 0 || y == 0)
        return Fixed!(128, false).init;
    else if (x == 1)
        return Fixed!(128, false)(y);
    else if (y == 1)
        return Fixed!(128, false)(x);
    else if (isPowerOfTwo(y))
        return Fixed!(128, false)(x) << ctz(y);
    else if (isPowerOfTwo(x))
        return Fixed!(128, false)(y) << ctz(x); 

    Fixed!(128, false) ret = Fixed!(128, false)((x >> 32) * (y >> 32), cast(ulong)(cast(uint)x) * cast(uint)y);
    ulong p1 = (x >> 32) * cast(uint)y;
    ulong p2 = x != y ? cast(uint)x * (y >> 32) : p1;
    auto save = ret.lo;
    ret.lo += p1 << 32;
    if (save > ret.lo)
        ++ret.hi;
    save = ret.lo;
    ret.lo += p2 << 32;
    if (save > ret.lo)
        ++ret.hi;
    ret.hi += p1 >> 32;
    ret.hi += p2 >> 32;
    return ret;
}

auto mul(T, U)(auto const ref T x, auto const ref U y) if (is(T == ulong) && (is(U == uint) || is(U == ushort) || is(U == ubyte)))
{
    // 00 00 x1 x0 *
    // 00 00 00 y0
    //-------------
    //       x0*y0
    //    x1*y0
    
    if (x == 0 || y == 0)
        return Fixed!(128, false).init;
    else if (x == 1)
        return Fixed!(128, false)(y);
    else if (y == 1)
        return Fixed!(128, false)(x);
    else if (isPowerOfTwo(y))
        return Fixed!(128, false)(x) << ctz(y);
    else if (isPowerOfTwo(x))
        return Fixed!(128, false)(y) << ctz(x); 

    Fixed!(128, false) ret = Fixed!(128, false)(0, cast(ulong)(cast(uint)x) * y);
    ulong p1 = (x >> 32) * y;
    auto save = ret.lo;
    ret.lo += p1 << 32;
    if (save > ret.lo)
        ++ret.hi;
    ret.hi += p1 >> 32;
    return ret;
}

auto mul(T, U)(auto const ref T x, auto const ref U y) if (isUnsignedFixed!T && isAnyUnsigned!U)
{
    static assert(bitWidth!U <= bitWidth!T, "Cannot multiply a value of type " ~ T.stringof ~ " with a value of type " ~ U.stringof);


    if (x == 0 || y == 0)
        return Fixed!(bitWidth!T * 2, false).init;
    else if (x == 1)
        return Fixed!(bitWidth!T * 2, false)(y);
    else if (y == 1)
        return Fixed!(bitWidth!T * 2, false)(x);
    else if (isPowerOfTwo(y))
        return Fixed!(bitWidth!T * 2, false)(x) << ctz(y);
    else if (isPowerOfTwo(x))
        return Fixed!(bitWidth!T * 2, false)(y) << ctz(x); 

    static if (bitWidth!U == bitWidth!T)
    {
        Fixed!(bitWidth!T * 2, false) ret = 
            Fixed!(bitWidth!T * 2, false)(mul(x.hi, y.hi), mul(x.lo, y.lo));
        T p1 = mul(x.hi, y.lo);
        T p2 = x != y ? mul(x.lo, y.hi) : p1;
        auto save = ret.lo;
        ret.lo += p1 << (bitWidth!T / 2);
        if (save > ret.lo)
            ++ret.hi;
        save = ret.lo;
        ret.lo += p2 << (bitWidth!T / 2);
        if (save > ret.lo)
            ++ret.hi;
        ret.hi += p1.hi;
        ret.hi += p2.hi;
    }
    else
    {
        Fixed!(bitWidth!T * 2, false) ret = 
            Fixed!(bitWidth!T * 2, false)(0, mul(x.lo, y));
        T p1 = mul(x.hi, y);
        auto save = ret.lo;
        ret.lo += p1 << (bitWidth!T / 2);
        if (save > ret.lo)
            ++ret.hi;
        ret.hi += p1.hi;
    } //39
    return ret;
}

auto clz(T)(auto const ref T x) if (isAnyIntegral!T)
{
    if (x == 0)
        return bitWidth!T;

    static if (bitWidth!T <= bitWidth!size_t)
        return bitWidth!T - 1 - bsr(x);
    else static if (is(T == ulong))
    {
        if (cast(uint)(x >> 32))
			return 31 - bsr(cast(uint)(x >> 32));
		else
			return 63 - bsr(cast(uint)x);
    }
    else
    {
        if (x.hi)
            return clz(x.hi);
        else
            return bitWidth!T / 2 + clz(x.lo);
    }
}

auto ctfe_ctz(ubyte x)
{
    if (x == 0)
        return 8;
    else
    {
        auto ret = 0;
        if (!(x & 0x0F)) { ret += 4; x >>= 4; }
        if (!(x & 0x03)) { ret += 2; x >>= 2; }
        if (!(x & 0x01)) { ++ret; }
        return ret;
    }
}

auto ctz(T)(auto const ref T x) if (isAnyIntegral!T)
{
    if (x == 0)
        return bitWidth!T;

    static if (bitWidth!T <= bitWidth!size_t)
        return bsf(x);
    else static if (is(T == ulong))
    {
        if (cast(uint)x)
			return bsf(cast(uint)x);
		else
			return bsf(cast(uint)(x >> 32)) + 32;
    }
    else
    {
        if (x.lo)
            return ctz(x.lo);
        else
            return bitWidth!T / 2 + ctz(x.hi);
    }
}

auto divmod(T, U)(auto const ref T x, auto const ref U y, out T r) if (isAnyUnsigned!T && isAnyUnsigned!U && canAssign!(T, U))
{
    int shift;
    T q;

    if (x == 0)
    {
        r = T(y);
        return T.init;
    }
    else if (x == y)
    {
        r = T.init;
        return T(1);
    }
    else if (x < y)
    {
        r = x;
        return T.init;
    }
    else if (y == 1)
    {
        r = T.init;
        return x;
    }
    else if (isPowerOfTwo(y))
    {
        r = x & (y - 1);
        return x >> ctz(y);
    }

    static if (bitWidth!T <= 64 && bitWidth!U <= 64)
    {
        r = x % y;
        return x / y;
    }
    else
    {
        r = T.init;
        if (!x.hi)
        {
            static if (bitWidth!U < bitWidth!T)
                return T(divmod(x.lo, y, r.lo));
            else
            {
                if (!y.hi)
                    return T(divmod(x.lo, y.lo, r.lo));
                r.lo = x.lo;
                return T.init;
            }
        }

        static if (bitWidth!U == bitWidth!T)
        {
            if (!y.lo)
            {
                if (!y.hi)        
                    return T(divmod(x.hi, y.lo, r.lo));
                if (!x.lo)
                    return T(divmod(x.hi, y.lo, r.hi));
                if (isPowerOfTwo(y.hi))
                {
                    r.lo = x.lo;
                    r.hi = x.hi & (y.hi - 1);
                    return T(x.hi >> ctz(y.hi));
                }
                shift = clz(y.hi) - clz(x.hi);
                if (shift > bitWidth!T / 2 - 2)
                {
                    r = x;
                    return T.init;
                }
                ++shift;
                q = x << (bitWidth!T / 2 - shift);
                r = x >> shift;                 
            }
            else
            {
                if (!y.hi)
                {
                    if (isPowerOfTwo(y.lo))
                    {
                        r.lo = x.lo & (y.lo - 1);
                        if (y.lo == 1)
                            return x;
                        return x >> (bitWidth!T / 2 - ctz(y.lo));
                    }
                    shift = 1 + bitWidth!T / 2 + clz(y.lo) - clz(x.hi);
                    q = x << (bitWidth!T - shift);
                    r = x >> shift;
                }
                else
                {
                    shift = clz(y.hi) - clz(x.hi);
                    if (shift > bitWidth!T / 2 - 1)
                    {
                        r = x;
                        return T.init;
                    }
                    ++shift;
                    q = x << (bitWidth!T - shift);
                    r = x >> shift;
                }
            }
        }
        else
        {
            if (!y)        
                return T(divmod(x.hi, y, r.lo));
            else
            {
                if (isPowerOfTwo(y))
                {
                    r.lo = x.lo & (y - 1);
                    if (y == 1)
                        return x;
                    return x >> (bitWidth!T / 2 - ctz(y));
                }
                enum leadingBits = bitWidth!T / 2 - bitWidth!U;
                shift = 1 + bitWidth!T / 2 + (leadingBits + clz(y)) - clz(x.hi); 
                q = x << (bitWidth!T - shift);
                r = x >> shift;
            }
        }

        uint carry;
        while (shift--)
        {
            r <<= 1;        
            q <<= 1;
            q |= carry;
            carry = r >= y;        
            if (carry)
                r -= y;                   
        }
        q <<= 1;
        q |= carry;
        return q;
    }
}

auto div(T, U)(auto const ref T x, auto const ref U y) if (isAnyUnsigned!T && isAnyUnsigned!U && canAssign!(T, U))
{
    int shift;

    if (x == 0)
        return T.init;
    else if (x == y)
        return T(1);
    else if (x < y)
        return T.init;
    else if (y == 1)
        return x;
    else if (isPowerOfTwo(y))
        return x >> ctz(y);

    static if (bitWidth!T <= 64 && bitWidth!U <= 64)
        return x / y;
    else
    {
        T q, r;

        if (!x.hi)
        {
            static if (bitWidth!U < bitWidth!T)
                return T(div(x.lo, y));
            else
            {
                if (!y.hi)
                    return T(div(x.lo, y.lo));
                return T.init;
            }
        }

        static if (bitWidth!U == bitWidth!T)
        {
            if (!y.lo)
            {
                if (!y.hi)        
                    return T(div(x.hi, y.lo));
                if (!x.lo)
                    return T(div(x.hi, y.lo));
                if (isPowerOfTwo(y.hi))
                    return T(x.hi >> ctz(y.hi));
                shift = clz(y.hi) - clz(x.hi);
                if (shift > bitWidth!T / 2 - 2)
                   return T.init;
                ++shift;
                q = x << (bitWidth!T / 2 - shift);
                r = x >> shift;                 
            }
            else
            {
                if (!y.hi)
                {
                    if (isPowerOfTwo(y.lo))
                    {
                        if (y.lo == 1)
                            return x;
                        return x >> (bitWidth!T / 2 - ctz(y.lo));
                    }
                    shift = 1 + bitWidth!T / 2 - clz(y.lo) - clz(x.hi);
                    q = x << (bitWidth!T - shift);
                    r = x >> shift;
                }
                else
                {
                    shift = clz(y.hi) - clz(x.hi);
                    if (shift > bitWidth!T / 2 - 1)
                    {
                        r = x;
                        return T.init;
                    }
                    ++shift;
                    q = x << (bitWidth!T - shift);
                    r = x >> shift;
                }
            }
        }
        else
        {
            if (!y)        
                return T(divmod(x.hi, y, r.lo));
            else
            {
                if (isPowerOfTwo(y))
                {
                    r.lo = x.lo & (x.lo - 1);
                    if (y == 1)
                        return x;
                    return x >> (bitWidth!T / 2 - ctz(y));
                }
                enum leadingBits = bitWidth!T / 2 - bitWidth!U;
                shift = 1 + bitWidth!T / 2 - (leadingBits + clz(y)) - clz(x.hi);
                q = x << (bitWidth!T - shift);
                r = x >> shift;
            }
        }

        uint carry;
        while (shift--)
        {
            r <<= 1;        
            q <<= 1;
            q |= carry;
            carry = r >= y;        
            if (carry)
                r -= y;                   
        }
        q <<= 1;
        q |= carry;
        return q;
    }
}

auto mod(T, U)(auto const ref T x, auto const ref U y) if (isAnyUnsigned!T && isAnyUnsigned!U && canAssign!(T, U))
{
    int shift;

    if (x == 0)
        return T(y);
    else if (x == y)
        return T.init;
    else if (x < y)
        return T(y);
    else if (y == 1)
        return T.init;
    else if (isPowerOfTwo(y))
        return x & (y - 1);

    static if (bitWidth!T <= 64 && bitWidth!U <= 64)
        return x % y;
    else
    {
        T r;
        if (!x.hi)
        {
            static if (bitWidth!U < bitWidth!T)
                return T(mod(x.lo, y));
            else
            {
                if (!y.hi)
                    return T(mod(x.lo, y.lo));
                return T(x.lo);
            }
        }

        static if (bitWidth!U == bitWidth!T)
        {
            if (!y.lo)
            {
                if (!y.hi)        
                    return T(mod(x.hi, y.lo));
                if (!x.lo)
                    return T(mod(x.hi, y.lo));
                if (isPowerOfTwo(y.hi))
                    return T(x.hi & (x.hi - 1), x.lo);
                shift = clz(y.hi) - clz(x.hi);
                if (shift > bitWidth!T / 2 - 2)
                    return x;
                ++shift;
                r = x >> shift;                 
            }
            else
            {
                if (!y.hi)
                {
                    if (isPowerOfTwo(y.lo))
                        return T(x.lo & (y.lo - 1));
                    shift = 1 + bitWidth!T / 2 - clz(y.lo) - clz(x.hi);
                    r = x >> shift;
                }
                else
                {
                    shift = clz(y.hi) - clz(x.hi);
                    if (shift > bitWidth!T / 2 - 1)
                        return x;
                    ++shift;
                    r = x >> shift;
                }
            }
        }
        else
        {
            if (!y)        
                return T(mod(x.hi, y));
            else
            {
                if (isPowerOfTwo(y))
                    return T(x.lo & (y - 1));
                enum leadingBits = bitWidth!T / 2 - bitWidth!U;
                shift = 1 + bitWidth!T / 2 - (leadingBits + clz(y)) - clz(x.hi);
                r = x >> shift;
            }
        }

        uint carry;
        while (shift--)
        {
            r <<= 1;              
            if (r >= y)
                r -= y;                   
        }
        return r;
    }
}


unittest
{
    void test(T)()
    {
        T zero = T(0);
        T one = T(1);
        T two = T(2);
        T three = T(3);
        T one2 = T(0, 1);
        T big = T(2000, 2);
        T bigm1 = T(2000, 1);
        T bigger = T(2001, 1);
        T biggest = T.max;
        assert (one < two);
        assert (two > one);
        assert (one < big);
        assert (big > one);
        assert (one == one2);
        assert (one != two);
        assert (big > two);
        assert (big > three);
        assert (bigm1 <= big);
        assert (bigm1 < big);
        assert (bigm1 != big);
        assert (big < biggest);
        assert (big <= biggest);
        assert (biggest > big);
        assert (biggest >= big);
        assert (big == ~~big);
        assert (one == (one | one));
        assert (big == (big | big));
        assert (one == (one | zero));
        assert (one == (one & one));
        assert (big == (big & big));
        assert (zero == (one & zero));
        assert (zero == (big & ~big));
        assert (zero == (one ^ one));
        assert (zero == (big ^ big));
        assert (one == (one ^ zero));
        assert (big == (big >> 0));
        assert (big == (big << 0));
        assert ((big << 1) > big);
        assert ((big >> 1) < big);
        assert (big == (big << 10) >> 10);
        assert (big == (big >> 1) << 1);
        assert (one == (one << 80) >> 80);
        assert (zero == (one >> 80) << 80);
        assert (zero + one == one);
        assert (one + one == two);
        assert (bigm1 + one == big);
        assert (one - zero == one);
        assert (one - one == zero);
        assert (zero - one == biggest);
        assert (big - big == zero);
        assert (big - bigm1 == one);
        assert (big - one == bigm1);
        assert (biggest + 1 == zero);
        assert (zero - 1 == biggest);
        assert (!!one);
        assert (!!!zero);
        assert (!zero);
        assert (zero == 0);
        assert (!(zero != 0));
        assert (!(one == 0));
        assert (one != 0);
        T test = zero;
        assert (++test == one);
        assert (test == one);
        assert (test++ == one);
        assert (test == two);
        assert ((test -= 2) == zero);
        assert (test == zero);
        assert ((test += 2) == two);
        assert (test == two);
        assert (--test == one);
        assert (test == one);
        assert (test-- == one);
        assert (test == zero);
        assert ((test |= three) == three);
        assert ((test &= one) == one);
        assert ((test ^= three) == two);
        assert ((test >>= 1) == one);
        assert ((test <<= 1) == two);
        assert (big == -(-big));
        assert (two == -((-one) - 1));
        assert ((test = 1) == 1);
        assert ((test += 4) == 5);
        assert ((test -= 3) == 2);
        T a, b, c;
        assert ((a = 0) == 0);
        assert ((b = 0) == 0);
        assert ((c = a * b) == 0);
        assert (big * 1 == big);
        assert (big * 2 == big << 1);
        assert (big * zero == zero);
        assert (big * one == big);
        assert (big * two == big << 1);
        assert (big / one == big);
        assert (big % one == 0);
        assert (big / 1 == big);
        assert (big % 1 == 0);
        assert (big / two == big >> 1);
        assert (bigm1 / two == bigm1 >> 1);       
        assert (big / 2 == big >> 1);
        assert (bigm1 / 2 == bigm1 >> 1);  
        assert (big % 2 == big - ((big / 2) * 2));
        assert (big % two == big - ((big / two) * two));
        assert (bigm1 % 2 == bigm1 - ((bigm1 / 2) * 2));
        assert (bigm1 % two == bigm1 - ((bigm1 / two) * two));
        assert (zero ^^ 0 == one);
        assert (zero ^^ 1 == zero);
        assert (zero ^^ 2 == zero);
        assert (zero ^^ 3 == zero);
        assert (one ^^ 0 == one);
        assert (one ^^ 1 == one);
        assert (one ^^ 2 == one);
        assert (one ^^ 3 == one);
        assert (two ^^ 0 == one);
        assert (two ^^ 1 == two);
        assert (two ^^ 2 == 4);
        assert (two ^^ 3 == 8);

        assert(to!string(T("0")) == "0");
        assert(to!string(T("123")) == "123");
        
        import std.format;

        assert(format("%s", T(987)) == "987");
        assert(format("%d", T(987)) == "987");
        assert(format("%04d", T(987)) == "0987");
        assert(format("%u", T(987)) == "987");
        assert(format("%i", T(987)) == "987");
        assert(format("%2s", T(987)) == "987");
        assert(format("%4s", T(987)) == " 987");
        assert(format("%x", T(987)) == "3db");
        assert(format("%X", T(987)) == "3DB");
        assert(format("%04X", T(987)) == "03DB");

 

    }
        

    void testi(T)()
    {
        T zero = T(0);
        T one = T(1);
        T minusOne = T(-1);
        T two = T(2);
        T minusTwo = T(-2);
        T three = T(3);
        T minusThree = T(-3);
        T one2 = T(0, 1);
        T minusOne2 = -one2;
        T big = T(2000, 2);
        T small = -big;
        T bigm1 = T(2000, 1);
        T smallm1 = -bigm1;
        T bigger = T(2001, 1);
        T smaller = -bigger;
        T biggest = T.max;
        T smallest = T.min;

        assert (one < two);
        assert (two > one);
        assert (one != two);
        assert (minusOne > minusTwo);
        assert (minusTwo < minusOne);
        assert (minusOne != minusTwo);
        assert (one > minusOne);
        assert (minusTwo < two);
        assert (one != minusOne);
        assert (one < big);
        assert (minusOne > small); 
    }

    test!uint128();
    test!uint256();
    test!uint512();

    testi!int128();
    testi!int256();
    testi!int512();

    //results from SpeedCrunch

    assert (uint128("0x0123456789ABCDEF0123456789ABCDEF") * uint128("0x0123456789ABCDEF0123456789ABCDEF") ==
            uint128("0xB94D0F77FE1940EEDCA5E20890F2A521"));
    assert (uint256("0x0123456789ABCDEF0123456789ABCDEF") * uint256("0x0123456789ABCDEF0123456789ABCDEF") ==
            uint256("0x14B66DC33F6ACDCA878D6495A927AB94D0F77FE1940EEDCA5E20890F2A521"));

    assert (uint256("0x0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF") *
            uint256("0x0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF") ==
            uint256("0x729b6a56d866788a95f43ce76b3fdcbcb94d0f77fe1940eedca5e20890f2a521"));

    


}