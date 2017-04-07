module barcode.qr.util;

// std.bitmanip.BitArray store bits in other order

struct BitBuffer
{
    ubyte[] data;
    int length;

    alias getBytes = data;

    void appendBits(long val, int len)
    {
        auto nlen = length + len;
        reserve(nlen);
        for (int i = len - 1; i >= 0; i--, length++)
            data[length>>3] |= ((val >> i) & 1) << (7-(length&7));
    }

    void reserve(int nlen)
    {
        if (nlen > data.length * 8)
            data.length += (nlen - data.length * 8 + 7) / 8;
    }

    void appendData(const(ubyte)[] arr, int len)
    {
        auto nlen = length + len;
        reserve(nlen);
        for (int i = 0; i < len; i++, length++)
        {
            int bit = (arr[i >> 3] >> (7-(i&7))) & 1;
            data[length>>3] |= bit << (7-(length & 7));
        }
    }

    bool opIndex(size_t i) const
    { return cast(bool)((data[i>>3] >> (7-(i&7))) & 1); }

    void opIndexAssign(int val, size_t i)
    {
        auto bit = cast(bool)val;
        data[i>>3] |= bit << (7-(i&7));
    }
}

unittest
{
    BitBuffer arr;
    arr.appendBits(0b101101, 4);
    assert (arr.length == 4);
    assert (arr[0] == true);
    assert (arr[1] == true);
    assert (arr[2] == false);
    assert (arr[3] == true);
    arr.appendBits(0b101, 3);
    assert (arr.length == 7);
    assert (arr[4] == true);
    assert (arr[5] == false);
    assert (arr[6] == true);

    arr[5] = 1;
    assert (arr[5] == true);
}
