module fixed.uint128;

struct uint128
{
    version (LittleEndian)
	{
		ulong lo, hi;
	}
	else
	{
		ulong hi, lo;
	}
}