import std.stdio;
import std.string;
import std.getopt;

import barcode;

enum Code
{
    qr,
    code128,
    code39,
    ean13
}

int main(string[] args)
{
    if (args.length < 3)
    {
        import std.traits;
        stderr.writefln("use: gen [-o<FILE>] -c<CODE> <STRING>\n<CODE>: %s", [EnumMembers!Code]);
        return 1;
    }

    string output = "output.svg";
    Code code = Code.qr;

    getopt(args,
            "output|o", &output,
            "code|c", &code,
            );

    string str = args[1..$].join(" ");

    writeln("output: ", output);
    writeln("  code: ", code);
    writeln("  data: ", str);

    BarCodeEncoder enc;

    import barcode.qr : ECL;
    final switch (code)
    {
        case Code.qr: enc = new Qr(ECL.high); break;
        case Code.code128: enc = new Code128; break;
        case Code.code39: enc = new Code39; break;
        case Code.ean13: enc = new EAN13; break;
    }

    auto f = File(output, "w");

    auto bbcsd = new BaseBarCodeSvgDrawer;
    bbcsd.fixSizeMode = true;
    bbcsd.W = 400;
    bbcsd.H = 50;
    if (code == Code.qr)
        bbcsd.H = 400;
    f.write(bbcsd.draw(enc.encode(str)));

    return 0;
}
