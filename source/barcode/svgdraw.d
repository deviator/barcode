///
module barcode.svgdraw;

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
    string draw(BarCode bc)
    {
        import std.string : format, join;
        import std.conv : text;

        string bgStr;
        if (withBackground)
            bgStr = `<rect width="100%" height="100%" fill="`~bgColor~`" stroke-width="0"/>`;

        auto cW = W, cH = H;

        if (fixSizeMode)
        {
            cW /= bc.width;
            cH /= bc.height;
        }

        string[] paths;

        foreach (long y; 0..bc.height)
            foreach (long x; 0..bc.width)
            {
                if (bc[x,y]) paths ~= "M%s,%sh%sv%sh-%sz"
                    .format((x)*cW+borderX, (y)*cH+borderY, cW, cH, cW);
            }

        long w = cast(long)(bc.width * cW + borderX * 2);
        long h = cast(long)(bc.height * cH + borderY * 2);

        return text(`<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg xmlns="http://www.w3.org/2000/svg" version="1.1" viewBox="0 0 `, w, " ", h, `">
    `, bgStr, `
    <path d="`, paths.join(" "), `" fill="`, fgColor, `" stroke-width="0"/>
</svg>`);
    }
}