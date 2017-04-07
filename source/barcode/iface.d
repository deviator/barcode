module barcode.iface;

public import std.bitmanip : BitArray;

///
interface BarCodeEncoder1D
{
    ///
    BitArray encode(string str);
}

///
struct BarCode2D
{
    ///
    uint width;
    ///
    BitArray data;
}

///
interface BarCodeEncoder2D
{
    ///
    BarCode2D encode(string str);
}
