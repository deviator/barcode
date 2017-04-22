import std.algorithm;
import std.stdio;
import std.string;
import std.getopt;
import std.conv : text;

import barcode;

enum listNames = ["Qr", "Code128", "Code39", "EAN13", "ITF"];

int fail(string msg="", bool usage=true)
{
    if (msg != "") stderr.writeln(msg);
    if (usage) stderr.writefln("use: gen [-o<FILE>] %-(%s %) <STRING>", listNames.map!(a=>"[-"~a~"]"));
    return 1;
}

int main(string[] args)
{
    if (args.length < 2) return fail();

    string output = "output.svg";
    getopt(args, std.getopt.config.passThrough, "output|o", &output);
    args = args[1..$]; // first is program name

    BarCodeEncoder[string] list;

    size_t nn;

    foreach (i, arg; args)
    {
        nn = i;
        if (arg.startsWith("-"))
        {
            if(!listNames.canFind(arg[1..$]))
                return fail(text("unkonwn arg: ", arg));

            mixin (mix);
        }
        else break;
    }

    if (list.length == 0) list[listNames[0]] = mixin("new " ~ listNames[0]);

    auto str = args[nn..$].join(" ");

    writeln ("output: ", output);
    writefln("   use: %-(%s, %)", list.keys);
    writeln ("  data: ", str);

    auto bbcsd = new BaseBarCodeSvgDrawer;
    bbcsd.fixSizeMode = true;
    bbcsd.W = 400;

    foreach (enc; list.values)
    {
        auto bc = enc.encode(str);
        bbcsd.H = bc.type == "qrcode" ? 400 : 50;
        auto f = File(bc.type ~ "_" ~ output, "w");
        f.write(bbcsd.draw(bc));
    }

    return 0;
}

string mix() pure
{
    string[] ret;

    foreach (n; listNames)
        ret ~= text(`if (arg[1..$] == "`, n, `") list["`, n, `"] = new `, n ,`;`);

    return ret.join('\n');
}