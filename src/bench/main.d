
import fixed.uint128;

import g = fixed.internal.uint128gen;
version (D_InlineAsm_X86)
{
    import a = fixed.internal.uint128x8632;
}
else version (D_InlineAsm_X86_64)
{
    import a = fixed.internal.uint128x8664;
}
else
{
    import a = fixed.internal.uint128gen;
}

uint128[1000] ag, aa;

import std.random;

static this()
{
    for(size_t i = 0; i < 1000; ++i)
    {
        ag[i].lo = uniform(ulong.min, ulong.max);
        ag[i].hi = uniform(ulong.min, ulong.max);
        aa[i] = ag[i];
    }
}



import std.stdio;
import std.datetime;

pragma(inline, false)
void testincg()
{
    for(size_t i = 0; i < 1000; ++i)
        g.inc128(ag[i]);
}

void testinca()
{
    for(size_t i = 0; i < 1000; ++i)
        a.inc128(aa[i]);
}

void testnotg()
{
    for(size_t i = 0; i < 1000; ++i)
        g.not128(ag[i]);
}

void testnota()
{
    for(size_t i = 0; i < 1000; ++i)
        a.not128(aa[i]);
}

void testdecg()
{
    for(size_t i = 0; i < 1000; ++i)
        g.dec128(ag[i]);
}

void testdeca()
{
    for(size_t i = 0; i < 1000; ++i)
        a.dec128(aa[i]);
}

void testnegg()
{
    for(size_t i = 0; i < 1000; ++i)
        g.neg128(ag[i]);
}

void testnega()
{
    for(size_t i = 0; i < 1000; ++i)
        a.neg128(aa[i]);
}

void testandg()
{
    for(size_t i = 0; i < 999; ++i)
        g.and128(ag[i], ag[i + 1]);
}

void testanda()
{
    for(size_t i = 0; i < 999; ++i)
        a.and128(aa[i], aa[i + 1]);
}

void testorg()
{
    for(size_t i = 0; i < 999; ++i)
        g.or128(ag[i], ag[i + 1]);
}

void testora()
{
    for(size_t i = 0; i < 999; ++i)
        a.or128(aa[i], aa[i + 1]);
}

void testxorg()
{
    for(size_t i = 0; i < 999; ++i)
        g.xor128(ag[i], ag[i + 1]);
}

void testxora()
{
    for(size_t i = 0; i < 999; ++i)
        a.xor128(aa[i], aa[i + 1]);
}

void testaddg()
{
    for(size_t i = 0; i < 999; ++i)
        g.add128(ag[i], ag[i + 1]);
}

void testadda()
{
    for(size_t i = 0; i < 999; ++i)
        a.add128(aa[i], aa[i + 1]);
}

void testsubg()
{
    for(size_t i = 0; i < 999; ++i)
        g.sub128(ag[i], ag[i + 1]);
}

void testsuba()
{
    for(size_t i = 0; i < 999; ++i)
        a.sub128(aa[i], aa[i + 1]);
}

bool testarrays()
{
    for(size_t i = 0; i < 1000; ++i)
        if (ag[i] != aa[i])
            return false;
    return true;
}

void performTest(string func)()
{
    auto results = mixin("benchmark!(test" ~ func ~ "g, test" ~ func ~ "a)(1)");
    auto ret = testarrays() ? "OK" : "FAIL";
    auto ratio = cast(real)(results[0].length) /  cast(real)(results[1].length);
    writefln("%-10s %8d %8d %6.2f %-10s", func, results[0].length, results[1].length,ratio,ret);
}

int main(string[] argv)
{
    writeln("Testing and benchmarking...");
    writeln();
    writefln("%-10s %8s %8s %6s %-10s", "Test", "D", "Asm", "Ratio", "Test");
    writefln("----------------------------------------------");
    performTest!"inc"();
    performTest!"dec"();
    performTest!"not"();
    performTest!"neg"();
    performTest!"and"();
    performTest!"or"();
    performTest!"xor"();
    performTest!"add"();
    performTest!"sub"();
    writefln("----------------------------------------------");
    writeln();
    writeln("Press enter to quit");
	getchar();
    return 0;
}



