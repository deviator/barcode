///
module barcode.code39;

import std.experimental.logger;

import std.exception;
import std.string;
import std.range;
import std.array;
import std.typecons : tuple;

import barcode.iface;

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

enum ushort[char] table = getDict!((i,a) => tuple(a.ch, a.mask))(src_data);
enum ushort[char] checkVal = getDict!((i,a) => tuple(a.ch, i))(src_data);
enum char[ushort] checkValInv = getDict!((i,a) => tuple(cast(ushort)i, a.ch))(src_data);

struct Sym { char ch; ushort mask; }

enum src_data =
[
    Sym('0', 0b000110100),
    Sym('1', 0b100100001),
    Sym('2', 0b001100001),
    Sym('3', 0b101100000),
    Sym('4', 0b000110001),
    Sym('5', 0b100110000),
    Sym('6', 0b001110000),
    Sym('7', 0b000100101),
    Sym('8', 0b100100100),
    Sym('9', 0b001100100),
    Sym('A', 0b100001001),
    Sym('B', 0b001001001),
    Sym('C', 0b101001000),
    Sym('D', 0b000011001),
    Sym('E', 0b100011000),
    Sym('F', 0b001011000),
    Sym('G', 0b000001101),
    Sym('H', 0b100001100),
    Sym('I', 0b001001100),
    Sym('J', 0b000011100),
    Sym('K', 0b100000011),
    Sym('L', 0b001000011),
    Sym('M', 0b101000010),
    Sym('N', 0b000010011),
    Sym('O', 0b100010010),
    Sym('P', 0b001010010),
    Sym('Q', 0b000000111),
    Sym('R', 0b100000110),
    Sym('S', 0b001000110),
    Sym('T', 0b000010110),
    Sym('U', 0b110000001),
    Sym('V', 0b011000001),
    Sym('W', 0b111000000),
    Sym('X', 0b010010001),
    Sym('Y', 0b110010000),
    Sym('Z', 0b011010000),
    Sym('-', 0b010000101),
    Sym('.', 0b110000100),
    Sym(' ', 0b011000100),
    Sym('$', 0b010101000),
    Sym('/', 0b010100010),
    Sym('+', 0b010001010),
    Sym('%', 0b000101010),
    Sym('*', 0b010010100)
];

auto getDict(alias F, T)(T[] arr)
{
    alias frt = typeof(F(size_t(0), T.init));
    alias KEY = typeof(frt.init[0]);
    alias VAL = typeof(frt.init[1]);

    VAL[KEY] ret;
    foreach (i, e; arr)
    {
        auto tmp = F(i, e);
        ret[tmp[0]] = tmp[1];
    }
    return ret;
}

unittest
{
    static struct X { char ch; ushort mask; }
    enum data = [ X('0', 0b001), X('1', 0b010), X('2', 0b100), ];

    {
        enum ushort[char] t = getDict!((i,a) => tuple(a.ch, a.mask))(data);
        static assert(t.keys.length == 3);
        assert('0' in t);
        assert(t['0'] == 0b001);
        assert('1' in t);
        assert(t['1'] == 0b010);
        assert('2' in t);
        assert(t['2'] == 0b100);
    }

    {
        enum ushort[char] t = getDict!((i,a) => tuple(a.ch, i))(data);
        static assert(t.keys.length == 3);
        assert('0' in t);
        assert(t['0'] == 0);
        assert('1' in t);
        assert(t['1'] == 1);
        assert('2' in t);
        assert(t['2'] == 2);
    }

    {
        enum char[ubyte] t = getDict!((i,a) => tuple(cast(ubyte)i, a.ch))(data);
        static assert(t.keys.length == 3);
        assert(0 in t);
        assert(t[0] == '0');
        assert(1 in t);
        assert(t[1] == '1');
        assert(2 in t);
        assert(t[2] == '2');
    }
}
