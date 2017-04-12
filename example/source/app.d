import std.stdio;
import std.string;
import std.getopt;

import barcode;

class ListEncoder : BarCodeEncoder
{
    BarCodeEncoder[] list;
    size_t cur;

    this(BarCodeEncoder[] lst...)
    { list = lst; }

    BarCode encode(string str)
    { return list[cur++%$].encode(str); }
}

int main(string[] args)
{
    if (args.length < 2)
    {
        import std.traits;
        stderr.writefln("use: gen [-o<FILE>] [--qr] [--code128] [--code39] [--ean13] <STRING>");
        return 1;
    }

    string output = "output.svg";
    bool useQr, useCode128, useCode39, useEAN13;

    getopt(args,
            "output|o", &output,
            "qr", &useQr,
            "code128", &useCode128,
            "code39", &useCode39,
            "ean13", &useEAN13
            );

    if (!(useQr || useCode128 || useCode39 || useEAN13))
        useQr = true;

    string str = args[1..$].join(" ");

    writeln("output: ", output);
    writefln(" codes: Qr %s, Code128 %s, Code39 %s, EAN13 %s",
                      useQr, useCode128, useCode39, useEAN13);
    writeln("  data: ", str);

    import barcode.qr : ECL;
    auto enc = new ListEncoder(
        (useQr ? cast(BarCodeEncoder[])[new Qr(ECL.high)] : []) ~
        (useCode128 ? cast(BarCodeEncoder[])[new Code128] : []) ~
        (useCode39 ? cast(BarCodeEncoder[])[new Code39] : []) ~
        (useEAN13 ? cast(BarCodeEncoder[])[new EAN13] : [])
    );

    auto bbcsd = new BaseBarCodeSvgDrawer;
    bbcsd.fixSizeMode = true;
    bbcsd.W = 400;
    bbcsd.H = 50;

    foreach (i; 0 .. enc.list.length)
    {
        auto bc = enc.encode(str);
        bbcsd.H = bc.type == "qrcode" ? 400 : 50;
        auto f = File(bc.type ~ "_" ~ output, "w");
        f.write(bbcsd.draw(bc));
    }

    return 0;
}