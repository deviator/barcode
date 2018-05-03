///
module barcode.svgdraw;

import std.string : format, join;
import std.conv : text;

import barcode.types;

///
interface BarCodeSvgDrawer
{
    ///
    string draw(BarCode bc);
}

///
class BaseBarCodeSvgDrawer : BarCodeSvgDrawer
{
    ///
    bool fixSizeMode = false;
    ///
    bool withBackground = true;

    ///
    float borderX=50.0f, borderY=50.0f;
    ///
    float W=10.0f, H=10.0f;

    string bgColor = "#FFFFFF";
    string fgColor = "#000000";

    ///
    struct DrawData
    {
        ///
        string svgpath;
        ///
        long w, h;
    }

    DrawData buildPath(BarCode bc)
    {
        auto cW = W, cH = H;

        if (fixSizeMode)
        {
            cW /= bc.width;
            cH /= bc.height;
        }

        string[] paths;

        long start = -1;
        float len = 0;

        foreach (size_t y; 0..bc.height)
            foreach (size_t x; 0..bc.width)
            {
                if (bc[x,y])
                {
                    if (start == -1)
                        start = x;
                    len += cW;
                }

                if ((!bc[x,y] || x == bc.width-1) && start != -1)
                {
                    paths ~= "M%s,%sh%sv%sh-%sz"
                        .format(start*cW+borderX,
                                y*cH+borderY, len, cH, len);
                    start = -1;
                    len = 0;
                }
            }

        long w = cast(long)(bc.width * cW + borderX * 2);
        long h = cast(long)(bc.height * cH + borderY * 2);

        return DrawData(paths.join(" "), w, h);
    }

    ///
    string draw(BarCode bc)
    {
        string bgStr;
        if (withBackground)
            bgStr = `<rect width="100%" height="100%" fill="`~bgColor~`" stroke-width="0"/>`;

        auto dd = buildPath(bc);

        return text(`
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
            <svg xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="0 0 `, dd.w, " ", dd.h, `">
                `, bgStr, `
                <path d="`, dd.svgpath, `" fill="`, fgColor, `" stroke-width="0"/>
            </svg>`).flineOffset;
    }
}

class PseudoRasterBarCodeSvgDrawer : BaseBarCodeSvgDrawer
{
    override DrawData buildPath(BarCode bc)
    {
        auto cW = W, cH = H;

        if (fixSizeMode)
        {
            cW /= bc.width;
            cH /= bc.height;
        }

        string[] paths;

        long start = -1;
        float len = 0;

        foreach (size_t y; 0..bc.height)
            foreach (size_t x; 0..bc.width)
            {
                if (bc[x,y])
                    paths ~= "M%s,%sh%sv%sh-%sz"
                        .format(x*cW+borderX, y*cH+borderY, cW, cH, cW);
            }

        long w = cast(long)(bc.width * cW + borderX * 2);
        long h = cast(long)(bc.height * cH + borderY * 2);

        return DrawData(paths.join(" "), w, h);
    }
}

string flineOffset(string txt) @property
{
    import std.string;
    import std.algorithm;
    string[] res;
    ptrdiff_t offset = -1;
    foreach (ln; txt.splitLines.map!(a=>a.stripRight))
    {
        // skip empty lines
        auto sln = ln.strip;
        if (sln.length == 0)
        {
            if (res.length) res ~= "";
            continue;
        }

        if (offset == -1)
            offset = ln.length - sln.length;

        res ~= ln[min(offset, ln.length - sln.length)..$];
    }
    return res.join("\n");
}

unittest
{
    enum txt = ("    \n            some  \n            text   \n  "~
                 "   \n                here   \n\n            end  ").flineOffset;
    enum exp = "some\ntext\n\n    here\n\nend";

    static assert(txt == exp);
}

unittest
{
    enum txt = `
    some text
   with
  wrong formated
      lines`.flineOffset;
    enum exp = "some text\n" ~
               "with\n" ~
               "wrong formated\n" ~
               "  lines";
    static assert(txt == exp);
}