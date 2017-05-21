module barcode.types;

public import std.bitmanip : BitArray;

///
struct BarCode
{
    ///
    size_t width;
    ///
    BitArray data;
    ///
    string type;

    pure const
    {
        ///
        bool opIndex(size_t x, size_t y)
        {
            if (0 <= x && x < width &&
                0 <= y && y < height)
                return data[y*width+x];
            return false;
        }

        ///
        bool opIndex(size_t i)
        {
            if (0 <= i && i < data.length)
                return data[i];
            return false;
        }

        ///
        auto height() { return data.length / width; }
    }
}

///
interface BarCodeEncoder
{
    ///
    BarCode encode(string str);
}
