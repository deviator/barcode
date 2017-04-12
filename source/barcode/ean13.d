///
module barcode.ean13;

import std.experimental.logger;

import std.algorithm;
import std.exception;
import std.string;
import std.range;
import std.array;
import std.typecons : tuple;
import std.ascii;

import barcode.types;
import barcode.util;

///
class EAN13 : BarCodeEncoder
{
protected:

    enum lead_trailer = bitsStr!"#-#";
    enum separator = bitsStr!"-#-#-";

    enum Bits!ushort[10][2] modules_AB = [[
        bitsStr!"---##-#",
        bitsStr!"--##--#",
        bitsStr!"--#--##",
        bitsStr!"-####-#",
        bitsStr!"-#---##",
        bitsStr!"-##---#",
        bitsStr!"-#-####",
        bitsStr!"-###-##",
        bitsStr!"-##-###",
        bitsStr!"---#-##"
    ],
    [
        bitsStr!"-#--###",
        bitsStr!"-##--##",
        bitsStr!"--##-##",
        bitsStr!"-#----#",
        bitsStr!"--###-#",
        bitsStr!"-###--#",
        bitsStr!"----#-#",
        bitsStr!"--#---#",
        bitsStr!"---#--#",
        bitsStr!"--#-###"
    ]];

    enum Bits!ushort[10] modules_C = [
        bitsStr!"###--#-",
        bitsStr!"##--##-",
        bitsStr!"##-##--",
        bitsStr!"#----#-",
        bitsStr!"#-###--",
        bitsStr!"#--###-",
        bitsStr!"#-#----",
        bitsStr!"#---#--",
        bitsStr!"#--#---",
        bitsStr!"###-#--"
    ];

    enum ubyte[6][10] parities = [
    /+0+/[0, 0, 0, 0, 0, 0],
    /+1+/[0, 0, 1, 0, 1, 1],
    /+2+/[0, 0, 1, 1, 0, 1],
    /+3+/[0, 0, 1, 1, 1, 0],
    /+4+/[0, 1, 0, 0, 1, 1],
    /+5+/[0, 1, 1, 0, 0, 1],
    /+6+/[0, 1, 1, 1, 0, 0],
    /+7+/[0, 1, 0, 1, 0, 1],
    /+8+/[0, 1, 0, 1, 1, 0],
    /+9+/[0, 1, 1, 0, 1, 0]
    ];

    enum MODULE = 7;
    enum DIGITS = 12;
    enum WIDTH = lead_trailer.count * 2 + separator.count + MODULE + DIGITS;

public:

    override BarCode encode(string data)
    {
        enforce(data.length == DIGITS, format("length of data must be %s", DIGITS));
        enforce(data.all!isDigit, "all symbols must be a numbers");

        BitArray ret;

        size_t idx(char ch) { return cast(size_t)ch - cast(size_t)'0'; }
        void append(T)(Bits!T bb) { ret.addBits(bb); }

        append(lead_trailer);

        int checkSum = 0;
        foreach (i; 0 .. DIGITS)
            checkSum += (i%2 == 1 ? 1 : 3) * idx(data[i]);

        checkSum %= 10;
        checkSum = checkSum == 0 ? 0 : 10 - checkSum;

        assert (checkSum >= 0 && checkSum < 10, "checkSum calc wrong");

        auto pp = parities[checkSum];

        foreach (i; 0 .. 6) append(modules_AB[pp[i]][idx(data[i])]);

        append(separator);

        foreach (i; 6 .. 12) append(modules_C[idx(data[i])]);

        append(lead_trailer);

        return BarCode(ret.length, ret, "ean13");
    }
}
