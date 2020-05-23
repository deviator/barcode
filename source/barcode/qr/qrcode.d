module barcode.qr.qrcode;

import std.experimental.logger;

import std.math : abs;
import std.algorithm;
import std.exception;
import std.string;
import std.range;
import std.bitmanip : BitArray;
import std.array;
import std.traits : EnumMembers;
import std.typecons : Tuple, tuple;

import barcode.qr.qrsegment;
import barcode.qr.util;
import barcode.qr.ecl;

struct QrCode
{ 
pure @safe:
    static QrCode encodeSegments(QrSegment[] segs, ECL ecl,
            int minVer=1, int maxVer=40, int mask=-1, bool boostecl=true)
    {
        int sv = -1;
        int usedbits;
        foreach (v; minVer .. maxVer+1)
        {
            auto capasity = getNumDataCodewords(v, ecl) * 8;
            usedbits = QrSegment.getTotalBits(segs, v);
            if (usedbits != -1 && usedbits <= capasity)
            {
                sv = v;
                break;
            }
            enforce(v != maxVer, new Exception("Too big data for qr"));
        }

        if (boostecl)
        {
            foreach (newecl; [ECL.medium, ECL.quartile, ECL.high])
                if (usedbits <= getNumDataCodewords(sv, newecl) * 8)
                    ecl = newecl;
        }

        auto capacitybits = getNumDataCodewords(sv, ecl) * 8;

        BitBuffer bb;
        foreach (i, seg; segs)
        {
            bb.appendBits(seg.mode.bits, 4);
            bb.appendBits(seg.numChars, seg.mode.numCharCountBits(sv));
            bb.appendData(seg.data, seg.bitLength);
        }

        bb.appendBits(0, min(4, capacitybits - bb.length));
        bb.appendBits(0, (8 - bb.length % 8) % 8);

        foreach (pad; [0xEC, 0x11].cycle)
        {
            if (bb.length >= capacitybits) break;
            bb.appendBits(pad, 8);
        }

        assert (bb.length % 8 == 0);

        return QrCode(bb, mask, sv, ecl);
    }

    int vers;
    int size;
    ECL ecl;
    int mask;

    BitArray modules;
    BitArray isFunction;

    size_t crd(int x, int y) const nothrow { return size * y + x; }

    this(BitBuffer bb, int mask, uint vers, ECL ecl) @trusted
    {
        enforce(-1 <= mask && mask <= 7, "unknown mask");
        enforce(1 <= vers && vers <= 40, "unknown vers");
        enforce(bb.length == getNumDataCodewords(vers, ecl) * 8);

        this.vers = vers;
        this.ecl = ecl;
        this.size = vers * 4 + 17;

        modules.length = size*size;
        isFunction.length = size*size;

        drawFunctionPatterns();
        auto allcw = appendErrorCorrection(bb.getBytes);
        drawCodewords(allcw);

        if (mask == -1)
        {
            auto minPenalty = int.max;
            foreach (i; 0 .. 8)
            {
                drawFormatBits(i);
                applyMask(i);
                int penalty = getPenaltyScore();
                if (penalty < minPenalty)
                {
                    mask = i;
                    minPenalty = penalty;
                }
                applyMask(i); // undoes the mask due to XOR
            }
        }

        assert (0 <= mask && mask <= 7);

        drawFormatBits(mask);
        applyMask(mask);
        this.mask = mask;
    }

    void drawFunctionPatterns()
    {
        foreach (i; 0 .. size)
        {
            setFunctionModule(6, i, i % 2 == 0);
            setFunctionModule(i, 6, i % 2 == 0);
        }

        drawFinderPattern(3, 3);
        drawFinderPattern(size - 4, 3);
        drawFinderPattern(3, size - 4);

        auto alignPatPos = getAlignmentPatternPosition(vers);
        auto n = cast(int)alignPatPos.length;
        auto skips = [[0,0], [0, n-1], [n-1,0]];

        foreach (int i; 0 .. n)
            foreach (int j; 0 .. n)
                if (!skips.canFind([i,j]))
                    drawAlignmentPattern(alignPatPos[i], alignPatPos[j]);

        drawFormatBits(0);
        drawVersion();
    }

    void drawFormatBits(int mask)
    {
        auto data = ecl.formatBits << 3 | mask;
        auto rem = data;

        foreach (i; 0 .. 10)
            rem = (rem << 1) ^ ((rem >> 9) * 0x537);

        data = data << 10 | rem;
        data ^= 0x5412;
        assert (data >> 15 == 0);

        bool checkI(int i) { return ((data >> i) & 1) != 0; }

        foreach (i; 0 .. 6)
            setFunctionModule(8, i, checkI(i));

        setFunctionModule(8, 7, checkI(6));
        setFunctionModule(8, 8, checkI(7));
        setFunctionModule(7, 8, checkI(8));

        foreach (i; 9 .. 15)
            setFunctionModule(14 - i, 8, checkI(i));

        foreach (i; 0 .. 8)
            setFunctionModule(size - 1 - i, 8, checkI(i));
        foreach (i; 8 .. 15)
            setFunctionModule(8, size - 15 + i, checkI(i));

        setFunctionModule(8, size - 8, true);
    }

    void drawVersion()
    {
        if (vers < 7) return;
        auto rem = vers;
        foreach (i; 0 .. 12)
            rem = (rem << 1) ^ ((rem >> 11) * 0x1F25);
        auto data = vers << 12 | rem;
        assert (data >> 18 == 0);

        foreach (i; 0 .. 18)
        {
            auto bit = ((data >> i) & 1) != 0;
            auto a = size - 11 + i % 3, b = i / 3;
            setFunctionModule(a, b, bit);
            setFunctionModule(b, a, bit);
        }
    }

    void drawFinderPattern(int x, int y)
    {
        foreach (i; -4 .. 5)
            foreach (j; -4 .. 5)
            {
                auto dist = max(abs(i), abs(j));
                auto xx = x + j, yy = y + i;

                if (0 <= xx && xx < size &&
                    0 <= yy && yy < size)
                    setFunctionModule(xx, yy, dist != 2 && dist != 4);
            }
    }

    void drawAlignmentPattern(int x, int y)
    {
        foreach (i; -2 .. 3)
            foreach (j; -2 .. 3)
                setFunctionModule(x+j, y+i, max(abs(i), abs(j)) != 1);
    }

    void setFunctionModule(int x, int y, bool isBlack) @trusted
    {
        modules[crd(x,y)] = isBlack;
        isFunction[crd(x,y)] = true;
    }

    auto appendErrorCorrection(const(ubyte)[] data) const
    {
        assert (data.length == getNumDataCodewords(vers, ecl));

        auto nb = numErrorCorrectionBlocks[ecl][vers]; // numblocks
        auto tc = numErrorCorrectionCodewords[ecl][vers]; // totalecc

        assert (tc % nb == 0);
        auto blen = tc / nb; // blockecclen
        // numshortblocks
        auto nsb = nb - getNumRawDataModules(vers) / 8 % nb;
        // shortblocklen
        auto sblen = getNumRawDataModules(vers) / 8 / nb;

        ubyte[][] blocks;
        auto rs = ReadSolomonGenerator(blen);
        int k = 0;

        foreach (i; 0 .. nb)
        {
            auto l = k+sblen-blen+(i<nsb?0:1);
            auto dat = data[k..l];
            k += dat.length;
            auto ecc = rs.getRemainder(dat);
            if (i < nsb) dat ~= 0;
            dat ~= ecc;
            blocks ~= dat.dup;
        }

        ubyte[] res;
        foreach (i; 0 .. blocks[0].length)
            foreach(j, blk; blocks)
                if (i != sblen - blen || j >= nsb)
                    res ~= blk[i];

        assert (res.length == getNumRawDataModules(vers) / 8);

        return res;
    }

    void drawCodewords(const(ubyte)[] data) @trusted
    {
        size_t i = 0;
        for (int right = size - 1; right >= 1; right -= 2)
        {
            if (right == 6) right = 5;
            for (int vert = 0; vert < size; vert++)
            {
                for (int j = 0; j < 2; j++)
                {
                    int x = right - j;  // Actual x coordinate
                    bool upwards = ((right & 2) == 0) ^ (x < 6);
                    int y = upwards ? size - 1 - vert : vert;  // Actual y coordinate
                    if (!isFunction[crd(x,y)] && i < data.length * 8) {
                        modules[crd(x,y)] = ((data[i >> 3] >> (7 - (i & 7))) & 1) != 0;
                        i++;
                    }
                }
            }
        }

        assert (i == data.length*8);
    }

    void applyMask(int mask) @trusted
    {
        enforce(0 <= mask && mask <= 7, new Exception("unknown mask"));

        auto masker = maskPatterns[mask];
        foreach (y; 0 .. size)
            foreach (x; 0 .. size)
                modules[crd(x,y)] = modules[crd(x,y)] ^
                                    ((masker(x, y) == 0) &&
                                     (!isFunction[crd(x,y)]));
    }

    enum maskPatterns = [
        (int x, int y) @safe @nogc pure nothrow { return (x + y) % 2; },
        (int x, int y) @safe @nogc pure nothrow { return  y % 2; },
        (int x, int y) @safe @nogc pure nothrow { return  x % 3; },
        (int x, int y) @safe @nogc pure nothrow { return (x + y) % 3; },
        (int x, int y) @safe @nogc pure nothrow { return (x / 3 + y / 2) % 2; },
        (int x, int y) @safe @nogc pure nothrow { return  x * y % 2 + x * y % 3; },
        (int x, int y) @safe @nogc pure nothrow { return (x * y % 2 + x * y % 3) % 2; },
        (int x, int y) @safe @nogc pure nothrow { return ((x + y) % 2 + x * y % 3) % 2; }
    ];

    int getPenaltyScore() @trusted
    {
        int res;

        foreach (y; 0 .. size)
        {
            auto clrx = modules[crd(0,y)];
            auto runx = 1;
            foreach (x; 1 .. size)
            {
                if (modules[crd(x,y)] != clrx)
                {
                    clrx = modules[crd(x,y)];
                    runx = 1;
                }
                else
                {
                    runx++;
                    if (runx == 5) res += Penalty.N1;
                    else if (runx > 5) res++;
                }
            }
        }

        foreach (x; 0 .. size)
        {
            auto clry = modules[crd(x,0)];
            auto runy = 1;
            foreach (y; 1 .. size)
            {
                if (modules[crd(x,y)] != clry)
                {
                    clry = modules[crd(x,y)];
                    runy = 1;
                }
                else
                {
                    runy += 1;
                    if (runy == 5) res += Penalty.N1;
                    else if (runy > 5) res += 1;
                }
            }
        }

        foreach (y; 0 .. size-1)
            foreach (x; 0 .. size-1)
                if (modules[crd(x,y)] == modules[crd(x+1,y)] &&
                    modules[crd(x,y)] == modules[crd(x,y+1)] &&
                    modules[crd(x,y)] == modules[crd(x+1,y+1)])
                    res += Penalty.N2;

        foreach (y; 0 .. size)
        {
            auto bits = 0;
            foreach (x; 0 .. size)
            {
                bits = ((bits << 1) & 0x7FF) | (modules[crd(x,y)] ? 1 : 0);
                if (x >= 10 && (bits == 0x05D || bits == 0x5D0))
                    res += Penalty.N3;
            }
        }

        foreach (x; 0 .. size)
        {
            auto bits = 0;
            foreach (y; 0 .. size)
            {
                bits = ((bits << 1) & 0x7FF) | (modules[crd(x,y)] ? 1 : 0);
                if (y >= 10 && (bits == 0x05D || bits == 0x5D0))
                    res += Penalty.N3;
            }
        }

        int black;
        foreach (i; 0..modules.length) if (modules[i]) black++;
        auto total = size*size;

        for (int k = 0; black*20 < (9-k)*total || black*20 > (11+k)*total; k++)
            res += Penalty.N4;

        return res;
    }

    int[] getAlignmentPatternPosition(int ver)
    {
        enforce(1 <= ver && ver <= 40, "Version number out of range");

        if (ver == 1) return [];

        int numAlign = ver / 7 + 2;
        int step = ver == 32 ? 26 :
            (ver * 4 + numAlign * 2 + 1) / (2 * numAlign - 2) * 2;
        int[] res;
        int sz = ver * 4 + 17;
        for (int i = 0, pos = sz - 7; i < numAlign - 1; i++, pos -= step)
            res = [pos] ~ res;
        return [6] ~ res;
    }

    static int getNumRawDataModules(int ver)
    {
        enforce(1 <= ver && ver <= 40, "Version number out of range");

        int res = (16 * ver + 128) * ver + 64;

        if (ver >= 2) {
            int numAlign = ver / 7 + 2;
            res -= (25 * numAlign - 10) * numAlign - 55;
            if (ver >= 7) res -= 18 * 2;
        }

        return res;
    }

    static int getNumDataCodewords(int ver, ECL ecl)
    {
        enforce(1 <= ver && ver <= 40, "unknown version");
        return getNumRawDataModules(ver) / 8
               - numErrorCorrectionCodewords[ecl][ver];
    }

    enum Penalty
    {
        N1 = 3,
        N2 = 3,
        N3 = 40,
        N4 = 10
    }

    enum numErrorCorrectionCodewords = [
        // Low
     [-1,  7,   10,   15,   20,   26,   36,   40,   48,   60,   72,
          80,   96,  104,  120,  132,  144,  168,  180,  196,  224,
         224,  252,  270,  300,  312,  336,  360,  390,  420,  450,
         480,  510,  540,  570,  570,  600,  630,  660,  720,  750],

        // Medium
     [-1, 10,   16,   26,   36,   48,   64,   72,   88,  110,  130,
         150,  176,  198,  216,  240,  280,  308,  338,  364,  416,
         442,  476,  504,  560,  588,  644,  700,  728,  784,  812,
         868,  924,  980, 1036, 1064, 1120, 1204, 1260, 1316, 1372],

        // Quartile
     [-1, 13,   22,   36,   52,   72,   96,  108,  132,  160,  192,
         224,  260,  288,  320,  360,  408,  448,  504,  546,  600,
         644,  690,  750,  810,  870,  952, 1020, 1050, 1140, 1200,
        1290, 1350, 1440, 1530, 1590, 1680, 1770, 1860, 1950, 2040],

        // High
     [-1, 17,   28,   44,   64,   88,  112,  130,  156,  192,  224,
         264,  308,  352,  384,  432,  480,  532,  588,  650,  700,
         750,  816,  900,  960, 1050, 1110, 1200, 1260, 1350, 1440,
        1530, 1620, 1710, 1800, 1890, 1980, 2100, 2220, 2310, 2430]
    ];

    enum numErrorCorrectionBlocks = [
     [-1, 1,  1,  1,  1,  1,  2,  2,  2,  2,  4,
          4,  4,  4,  4,  6,  6,  6,  6,  7,  8,
          8,  9,  9, 10, 12, 12, 12, 13, 14, 15,
         16, 17, 18, 19, 19, 20, 21, 22, 24, 25],

     [-1, 1,  1,  1,  2,  2,  4,  4,  4,  5,  5,
          5,  8,  9,  9, 10, 10, 11, 13, 14, 16,
         17, 17, 18, 20, 21, 23, 25, 26, 28, 29,
         31, 33, 35, 37, 38, 40, 43, 45, 47, 49],

     [-1, 1,  1,  2,  2,  4,  4,  6,  6,  8,  8,
          8, 10, 12, 16, 12, 17, 16, 18, 21, 20,
         23, 23, 25, 27, 29, 34, 34, 35, 38, 40,
         43, 45, 48, 51, 53, 56, 59, 62, 65, 68],

     [-1, 1,  1,  2,  4,  4,  4,  5,  6,  8,  8,
         11, 11, 16, 16, 18, 16, 19, 21, 25, 25,
         25, 34, 30, 32, 35, 37, 40, 42, 45, 48,
         51, 54, 57, 60, 63, 66, 70, 74, 77, 81]
    ];

    static struct ReadSolomonGenerator
    {
    pure:
    private:
        ubyte[] coefficients;

        static ubyte multiply(ubyte x, ubyte y)
        {
            // Russian peasant multiplication
            int z = 0;
            for (int i = 7; i >= 0; i--)
            {
                z = (z << 1) ^ ((z >> 7) * 0x11D);
                z ^= ((y >> i) & 1) * x;
            }
            assert (z >> 8 == 0, "Assertion error");
            return cast(ubyte)z;
        }

    public:

        this(int degree)
        {
            enforce(2 <= degree && degree <= 254, "Degree out of range");

            // Start with the monomial x^0
            coefficients.length = degree;
            coefficients[$-1] = 1;

            // Compute the product polynomial (x - r^0) * (x - r^1) * (x - r^2) * ... * (x - r^{degree-1}),
            // drop the highest term, and store the rest of the coefficients in order of descending powers.
            // Note that r = 0x02, which is a generator element of this field GF(2^8/0x11D).
            int root = 1;
            foreach (i; 0 .. degree)
            {
                // Multiply the current product by (x - r^i)
                foreach (j, ref c; coefficients)
                {
                    c = multiply(c, cast(ubyte)root);
                    if (j + 1 < coefficients.length)
                        c ^= coefficients[j+1];
                }
                root = (root << 1) ^ ((root >> 7) * 0x11D);  // Multiply by 0x02 mod GF(2^8/0x11D)
            }
        }

        ubyte[] getRemainder(const(ubyte)[] data) const
        {
            // Compute the remainder by performing polynomial division
            auto result = new ubyte[](coefficients.length);//coefficients.dup;
            foreach (ref val; data)
            {
                ubyte factor = val ^ result.front;
                result.popFront;
                result ~= 0;
                foreach (j; 0 .. result.length)
                    result[j] ^= multiply(coefficients[j], factor);
            }
            return result;
        }
    }
}
