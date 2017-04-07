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

import barcode.iface;

///
class EAN13 : BarCodeEncoder1D
{
protected:

    enum ubyte[] quiet_zone = [0, 0, 0, 0, 0, 0, 0, 0, 0];
    enum ubyte[] lead_trailer = [1, 0, 1];
    enum ubyte[] separator = [0, 1, 0, 1, 0];

    enum ubyte[7][10][2] modules_AB = [[
        [0, 0, 0, 1, 1, 0, 1],
        [0, 0, 1, 1, 0, 0, 1],
        [0, 0, 1, 0, 0, 1, 1],
        [0, 1, 1, 1, 1, 0, 1],
        [0, 1, 0, 0, 0, 1, 1],
        [0, 1, 1, 0, 0, 0, 1],
        [0, 1, 0, 1, 1, 1, 1],
        [0, 1, 1, 1, 0, 1, 1],
        [0, 1, 1, 0, 1, 1, 1],
        [0, 0, 0, 1, 0, 1, 1]
    ],
    [
        [0, 1, 0, 0, 1, 1, 1],
        [0, 1, 1, 0, 0, 1, 1],
        [0, 0, 1, 1, 0, 1, 1],
        [0, 1, 0, 0, 0, 0, 1],
        [0, 0, 1, 1, 1, 0, 1],
        [0, 1, 1, 1, 0, 0, 1],
        [0, 0, 0, 0, 1, 0, 1],
        [0, 0, 1, 0, 0, 0, 1],
        [0, 0, 0, 1, 0, 0, 1],
        [0, 0, 1, 0, 1, 1, 1]
    ]];

    enum ubyte[7][10] modules_C = [
        [1, 1, 1, 0, 0, 1, 0],
        [1, 1, 0, 0, 1, 1, 0],
        [1, 1, 0, 1, 1, 0, 0],
        [1, 0, 0, 0, 0, 1, 0],
        [1, 0, 1, 1, 1, 0, 0],
        [1, 0, 0, 1, 1, 1, 0],
        [1, 0, 1, 0, 0, 0, 0],
        [1, 0, 0, 0, 1, 0, 0],
        [1, 0, 0, 1, 0, 0, 0],
        [1, 1, 1, 0, 1, 0, 0]
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
    enum WIDTH = quiet_zone.length * 2 + lead_trailer.length * 2 + separator.length + MODULE + DIGITS;

public:

    BitArray encode(string data)
    {
        enforce(data.length == DIGITS, format("length of data must be %s", DIGITS));
        enforce(data.all!isDigit);

        BitArray ret;

        size_t idx(char ch) { return cast(size_t)ch - cast(size_t)'0'; }
        void append(ubyte[] arr) { ret ~= BitArray(arr.map!(a => a != 0).array); }

        append(quiet_zone);

        append(lead_trailer);

        int checkSum = 0;
        foreach (i; 0 .. DIGITS)
            checkSum += (i%2 == 1 ? 1 : 3) * idx(data[i]);

        checkSum %= 10;
        checkSum = checkSum == 0 ? 0 : 10 - checkSum;

        assert (checkSum >= 0 && checkSum < 10, "checkSum calc wrong");

        auto pp = parities[checkSum];

        foreach (i; 0 .. 6)
            append(modules_AB[pp[i]][idx(data[i])]);

        append(separator);

        foreach (i; 6 .. 12)
            append(modules_C[idx(data[i])]);

        append(lead_trailer);
        append(quiet_zone);

        return ret;
    }
}
