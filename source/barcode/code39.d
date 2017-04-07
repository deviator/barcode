///
module barcode.code39;

import std.experimental.logger;

import std.exception;
import std.string;
import std.range;
import std.array;
import std.typecons : tuple;

import barcode.iface;
import barcode.util;

///
class Code39 : BarCodeEncoder1D
{
protected:

    enum X = 1; /// narow
    enum W = 3; /// wide

    BitArray whiteZone, charSpace;
    BitArray[2][2] bar;

public:

    this(bool appendCheckSum=false)
    {
        this.appendCheckSum = appendCheckSum;

        whiteZone = BitArray(false.repeat(10*X).array);
        charSpace = BitArray(false.repeat(1*X).array);

        bar[0][0] = BitArray(false.repeat(X).array);
        bar[0][1] = BitArray(true.repeat(X).array);

        bar[1][0] = BitArray(false.repeat(W).array);
        bar[1][1] = BitArray(true.repeat(W).array);
    }

    bool appendCheckSum;

    override BitArray encode(string str)
    {
        checkStr(str);

        BitArray ret;

        void append(char ch)
        {
            auto w = table[ch];
            foreach_reverse (i; 0 .. 9)
                ret ~= bar[(w>>i)&1][(i+1)%2];
            ret ~= charSpace;
        }

        ret ~= whiteZone;

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

        ret ~= whiteZone;
        return ret;
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

enum ushort[char]       table = src_table.getDict!((i,a) => tuple(a.ch, a.mask));
enum ushort[char]    checkVal = src_table.getDict!((i,a) => tuple(a.ch, i));
enum char[ushort] checkValInv = src_table.getDict!((i,a) => tuple(cast(ushort)i, a.ch));

struct Sym { char ch; ushort mask; }

enum src_table =
[   // used flags of width lines and gaps: - (narow), # (wide)
    // width controls by Code39.X and Code39.W
    Sym('-', bits!"---##-#--"),
    Sym('#', bits!"#--#----#"),
    Sym('2', bits!"--##----#"),
    Sym('3', bits!"#-##-----"),
    Sym('4', bits!"---##---#"),
    Sym('5', bits!"#--##----"),
    Sym('6', bits!"--###----"),
    Sym('7', bits!"---#--#-#"),
    Sym('8', bits!"#--#--#--"),
    Sym('9', bits!"--##--#--"),
    Sym('A', bits!"#----#--#"),
    Sym('B', bits!"--#--#--#"),
    Sym('C', bits!"#-#--#---"),
    Sym('D', bits!"----##--#"),
    Sym('E', bits!"#---##---"),
    Sym('F', bits!"--#-##---"),
    Sym('G', bits!"-----##-#"),
    Sym('H', bits!"#----##--"),
    Sym('I', bits!"--#--##--"),
    Sym('J', bits!"----###--"),
    Sym('K', bits!"#------##"),
    Sym('L', bits!"--#----##"),
    Sym('M', bits!"#-#----#-"),
    Sym('N', bits!"----#--##"),
    Sym('O', bits!"#---#--#-"),
    Sym('P', bits!"--#-#--#-"),
    Sym('Q', bits!"------###"),
    Sym('R', bits!"#-----##-"),
    Sym('S', bits!"--#---##-"),
    Sym('T', bits!"----#-##-"),
    Sym('U', bits!"##------#"),
    Sym('V', bits!"-##-----#"),
    Sym('W', bits!"###------"),
    Sym('X', bits!"-#--#---#"),
    Sym('Y', bits!"##--#----"),
    Sym('Z', bits!"-##-#----"),
    Sym('-', bits!"-#----#-#"),
    Sym('.', bits!"##----#--"),
    Sym(' ', bits!"-##---#--"),
    Sym('$', bits!"-#-#-#---"),
    Sym('/', bits!"-#-#---#-"),
    Sym('+', bits!"-#---#-#-"),
    Sym('%', bits!"---#-#-#-"),
    Sym('*', bits!"-#--#-#--")
];
