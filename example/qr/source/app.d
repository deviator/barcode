import std.stdio;
import barcode;
import barcode.qr;

import std.algorithm;
import std.range;
import std.string;
import std.random;
import std.array;

string rndNumber()
{
    auto cnt = uniform(3,128);
    return iota(cnt).map!(a=>"0123456789"[uniform(0,10)]).array;
}

string rndString()
{
    auto cnt = uniform(3,128);
    return iota(cnt).map!(a=>uniform!"[]"('A', 'z')).array.idup;
}

void main()
{
    enum ecl = ECL.high;
    foreach (i; 0 .. 10)
    {
        auto str = rndString();
        auto qr = QrCode.encodeText(str, ecl);
        auto f = File(str ~ ".svg", "w");
        f.write(qr.toSvgString(4));
    }
}
