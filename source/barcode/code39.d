///
module barcode.code39;

import std.experimental.logger;

import std.exception;
import std.string;
import std.range;
import std.array;
import std.typecons : tuple;

import barcode.types;
import barcode.util;

///
class Code39 : BarCodeEncoder
{
public:
    this(AppendCheckSum acs=AppendCheckSum.no) { appendCheckSum = acs; }

    AppendCheckSum appendCheckSum;

    override BarCode encode(string str)
    {
        checkStr(str);

        BitArray ret;

        void append(char ch) { ret.addBits(table[ch]); }

        append('*'); // start

        ushort checkSum;

        foreach (char c; str)
        {
            append(c);
            checkSum += checkVal[c];
        }

        checkSum %= 43;

        if (appendCheckSum)
            append(checkValInv[checkSum]);

        append('*'); // stop

        return BarCode(ret.length, ret, "code39");
    }

protected:

    void checkStr(string str)
    {
        foreach (char c; str)
        {
            enforce(c != '*', "symbol '*' is not allowed in code39");
            enforce(c in table, "symbol '" ~ c ~ "' is not allowed in code39");
        }
    }
}

private:

Bits!uint drawMask()(auto ref const Bits!ushort mask)
{
    enum X = 1;
    enum W = 3;

    uint val;
    uint cur = X;

    foreach (i; 0 .. mask.count)
    {
        auto black = (i%2) == 0;
        auto n = mask[i] ? W : X;
        foreach (k; 0 .. n)
            val |= black << cur++;
    }

    return Bits!uint(cur, val);
}

unittest
{
    auto v = drawMask(bitsStr!"--#--#-");
    assert(v == bitsStr!"#-###-#---#-");
}

enum Bits!uint[char]   table = src_table.getDict!((i,a) => tuple(a.ch, drawMask(a.mask)));
enum ushort[char]    checkVal = src_table.getDict!((i,a) => tuple(a.ch, i));
enum char[ushort] checkValInv = src_table.getDict!((i,a) => tuple(cast(ushort)i, a.ch));

struct Sym { char ch; Bits!ushort mask; }

unittest
{
    //                               W=3
    assert(table['0'] == bitsStr!"#-#---###-###-#-");
}

enum src_table =
[   // used flags of width lines and gaps: - (narow), # (wide)
    // width controls in drawMask function (X and W enums)
    Sym('0', bitsStr!"---##-#--"),
    Sym('1', bitsStr!"#--#----#"),
    Sym('2', bitsStr!"--##----#"),
    Sym('3', bitsStr!"#-##-----"),
    Sym('4', bitsStr!"---##---#"),
    Sym('5', bitsStr!"#--##----"),
    Sym('6', bitsStr!"--###----"),
    Sym('7', bitsStr!"---#--#-#"),
    Sym('8', bitsStr!"#--#--#--"),
    Sym('9', bitsStr!"--##--#--"),
    Sym('A', bitsStr!"#----#--#"),
    Sym('B', bitsStr!"--#--#--#"),
    Sym('C', bitsStr!"#-#--#---"),
    Sym('D', bitsStr!"----##--#"),
    Sym('E', bitsStr!"#---##---"),
    Sym('F', bitsStr!"--#-##---"),
    Sym('G', bitsStr!"-----##-#"),
    Sym('H', bitsStr!"#----##--"),
    Sym('I', bitsStr!"--#--##--"),
    Sym('J', bitsStr!"----###--"),
    Sym('K', bitsStr!"#------##"),
    Sym('L', bitsStr!"--#----##"),
    Sym('M', bitsStr!"#-#----#-"),
    Sym('N', bitsStr!"----#--##"),
    Sym('O', bitsStr!"#---#--#-"),
    Sym('P', bitsStr!"--#-#--#-"),
    Sym('Q', bitsStr!"------###"),
    Sym('R', bitsStr!"#-----##-"),
    Sym('S', bitsStr!"--#---##-"),
    Sym('T', bitsStr!"----#-##-"),
    Sym('U', bitsStr!"##------#"),
    Sym('V', bitsStr!"-##-----#"),
    Sym('W', bitsStr!"###------"),
    Sym('X', bitsStr!"-#--#---#"),
    Sym('Y', bitsStr!"##--#----"),
    Sym('Z', bitsStr!"-##-#----"),
    Sym('-', bitsStr!"-#----#-#"),
    Sym('.', bitsStr!"##----#--"),
    Sym(' ', bitsStr!"-##---#--"),
    Sym('$', bitsStr!"-#-#-#---"),
    Sym('/', bitsStr!"-#-#---#-"),
    Sym('+', bitsStr!"-#---#-#-"),
    Sym('%', bitsStr!"---#-#-#-"),
    Sym('*', bitsStr!"-#--#-#--")
];
