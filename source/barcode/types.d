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
        bool opIndex(long x, long y)
        {
            if (0 <= x && x < width &&
                0 <= y && y < height)
                return data[y*width+x];
            return false;
        }

        ///
        bool opIndex(long i)
        {
            if (0 <= i && i < data.length)
                return data[i];
            return false;
        }

        ///
        auto height() { return data.length / width; }
    }

    string toSvgString(bool cellSize=false)(int borderX, int borderY, float cellW, float cellH)
    {
        import std.exception : enforce;
        import std.string : format, join;

        enforce(borderX > 0 && borderY > 0, "border must be non-negative");
        enforce(cellW > 0 && cellH > 0, "size must be non-negative");

        static if(!cellSize)
        {
            cellW /= width;
            cellH /= height;
        }

        string[] paths;

        foreach (long y; -borderY .. this.height + borderY)
            foreach (long x; -borderX .. this.width + borderX)
            {
                if (this[x,y]) paths ~= "M%s,%sh%sv%sh-%sz"
                    .format((x+borderX)*cellW, (y+borderY)*cellH, cellW, cellH, cellW);
            }

        return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="0 0 %1$d %2$d">
    <rect width="100%%" height="100%%" fill="#FFFFFF" stroke-width="0"/>
    <path d="%3$s" fill="#000000" stroke-width="0"/>
</svg>`.format(cast(long)((this.width + borderX * 2)*cellW),
               cast(long)((this.height + borderY * 2)*cellH),
               paths.join(" "));
    }
}

///
interface BarCodeEncoder
{
    ///
    BarCode encode(string str);
}
