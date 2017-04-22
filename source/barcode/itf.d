/// Interleaved 2 of 5
module barcode.itf;

import std.algorithm;
import std.exception;
import std.string;
import std.range;
import std.array;
import std.typecons : tuple;
import std.ascii;
import std.conv : to;

import barcode.types;
import barcode.util;

///
class ITF : BarCodeEncoder
{
protected:

    // used flags of width lines and gaps: - (narow), # (wide)
    // width controls in drawMask function (X and W enums)
    enum start = bitsStr!"----";
    enum stop = bitsStr!"#--";

    enum Bits!ubyte[10] modules = [
        bitsStr!"--##-",
        bitsStr!"#---#",
        bitsStr!"-#--#",
        bitsStr!"##---",
        bitsStr!"--#-#",
        bitsStr!"#-#--",
        bitsStr!"-##--",
        bitsStr!"---##",
        bitsStr!"#--#-",
        bitsStr!"-#-#-",
    ];

public:
pure:
    ///
    this(AppendCheckSum acs=AppendCheckSum.no) { appendCheckSum = acs; }

    ///
    AppendCheckSum appendCheckSum;

    ///
    override BarCode encode(string sdata)
    {
        enforce(sdata.all!isDigit, "all symbols must be a numbers");

        auto data = sdata.map!(a=>cast(ubyte)(a-'0')).array;

        if (appendCheckSum) data ~= checkSum(data);
        if (data.length%2) data = [ubyte(0)] ~ data;

        assert (data.length%2 == 0);

        BitArray ret;
        ret.addBits(start.drawMask); 

        for (auto i = 0; i < data.length; i+=2)
            ret.addBits(combine(modules[data[i]], modules[data[i+1]]).drawMask);

        ret.addBits(stop.drawMask); 
        return BarCode(ret.length, ret, "itf");
    }
}

private:

Bits!ulong combine(A, B)(auto ref const Bits!A a, auto ref const Bits!B b)
{
    enforce(a.count == b.count);

    uint val;

    foreach (i; 0..a.count)
        val |= (b[i] | (a[i] << 1)) << (i*2);

    return Bits!ulong(a.count*2, val);
}

unittest
{
    assert (combine(bitsStr!"##", bitsStr!"--") == bitsStr!"#-#-");
    assert (combine(bitsStr!"#-", bitsStr!"-#") == bitsStr!"#--#");
    assert (combine(bitsStr!"#", bitsStr!"-") == bitsStr!"#-");
}

ubyte checkSum(ubyte[] data) pure
{
    uint a, b;

    foreach (i, ch; data)
        if (i%2) a += ch;
        else b += ch;

    if (data.length%2) b *= 3;
    else a *= 3;

    return (10 - (a+b)%10)%10;
}

unittest
{
    assert(checkSum("1937".map!(a=>cast(ubyte)(a-'0')).array) == 8);
}

Bits!ulong drawMask(T)(auto ref const Bits!T mask, bool bar=true)
{
    enum X = 1;
    enum W = 3;

    uint val, cur;

    bool black = !(bar ^ (mask.count%2));

    foreach (i; 0 .. mask.count)
    {
        foreach (k; 0 .. (mask[i] ? W : X))
            val |= black << cur++;
        black = !black;
    }

    return Bits!ulong(cur, val);
}

@system
unittest
{
    immutable v1 = I2Of5.start.drawMask;
    assert(v1 == bitsStr!"#-#-");
    const v2 = I2Of5.stop.drawMask;
    assert(v2 == bitsStr!"###-#");
    auto v3 = I2Of5.stop.drawMask(false);
    assert(v3 == bitsStr!"---#-");
}