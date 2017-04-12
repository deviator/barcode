module barcode.qr.qrsegment;

import std.algorithm;
import std.exception;
import std.ascii;

import barcode.qr.util;

struct QrSegment
{
pure:
    static struct Mode
    {
        enum numeric = Mode(1, [10, 12, 14]),
        alphanumeric = Mode(2, [ 9, 11, 13]),
               bytes = Mode(4, [ 8, 16, 16]),
               kanji = Mode(8, [ 8, 10, 12]);

        ubyte bits;
        private ubyte[3] cc;

    pure:
        ubyte numCharCountBits(int ver) const
        {
                 if ( 1 <= ver && ver <=  9) return cc[0];
            else if (10 <= ver && ver <= 26) return cc[1];
            else if (27 <= ver && ver <= 40) return cc[2];
            else throw new Exception("Version number out of range");
        }
    }

    Mode mode;
    int numChars;
    ubyte[] data;
    int bitLength;

    static QrSegment makeBytes(const(ubyte)[] d)
    { return QrSegment(Mode.bytes, cast(int)d.length, d, cast(int)d.length*8); }

    static QrSegment makeNumeric(string digits)
    {
	BitBuffer bb;
        int accumData = 0;
        int accumCount = 0;
        int charCount = 0;
        foreach (char c; digits)
        {
            if (c < '0' || c > '9')
                throw new Exception("String contains non-numeric " ~
                                     "characters in numeric mode");
            accumData = accumData * 10 + (c - '0');
            accumCount++;
            if (accumCount == 3)
            {
                bb.appendBits(accumData, 10);
                accumData = 0;
                accumCount = 0;
            }
            charCount++;
        }
        if (accumCount > 0)  // 1 or 2 digits remaining
            bb.appendBits(accumData, accumCount * 3 + 1);
        return QrSegment(Mode.numeric, charCount, bb.getBytes, cast(int)bb.length);
    }

    static QrSegment makeAlphanumeric(string text)
    {
	BitBuffer bb;
	int accumData = 0;
	int accumCount = 0;
	int charCount = 0;
        foreach (char c; text)
        {
            if (c < ' ' || c > 'Z')
                throw new Exception("String contains unencodable " ~
                                     "characters in alphanumeric mode");
            accumData = accumData * 45 + encodingTable[c - ' '];
            accumCount++;
            if (accumCount == 2)
            {
                bb.appendBits(accumData, 11);
                accumData = 0;
                accumCount = 0;
            }
            charCount++;
	}
	if (accumCount > 0)  // 1 character remaining
            bb.appendBits(accumData, 6);
	return QrSegment(Mode.alphanumeric, charCount, bb.getBytes, cast(int)bb.length);
    }

    static QrSegment[] makeSegments(string text)
    {
	// Select the most efficient segment encoding automatically
        if (text.length == 0) return [];
        else if (QrSegment.isNumeric(text))
            return [QrSegment.makeNumeric(text)];
        else if (QrSegment.isAlphanumeric(text))
            return [QrSegment.makeAlphanumeric(text)];
        else
            return [QrSegment.makeBytes(cast(ubyte[])text.dup)];
    }

    static bool isAlphanumeric(string text)
    {
        return text.map!(a=>cast(int)a)
            .all!(c => ' ' <= c && c <= 'Z' && encodingTable[c - ' '] != -1);
    }

    static bool isNumeric(string text) { return text.all!isDigit; }

    pure this(Mode md, int nc, const(ubyte)[] d, int bl)
    {
        mode = md;
        numChars = nc;
        data = d.dup;
        bitLength = bl;
    }

    static int getTotalBits(const(QrSegment)[] segs, int vers)
    {
        enforce(1 <= vers && vers <= 40, "unknown vers");
	int result = 0;
        foreach (seg; segs)
        {
            int ccbits = seg.mode.numCharCountBits(vers);
            if (seg.numChars >= (1 << ccbits))
                return -1;
            result += 4 + ccbits + seg.bitLength;
        }
	return result;
    }

private:
    enum byte[59] encodingTable = [
        // SP,  !,  ",  #,  $,  %,  &,  ',  (,  ),  *,  +,  ,,  -,  .,  /,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9,  :,  ;,  <,  =,  >,  ?,  @,  // ASCII codes 32 to 64
            36, -1, -1, -1, 37, 38, -1, -1, -1, -1, 39, 40, -1, 41, 42, 43,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 44, -1, -1, -1, -1, -1, -1,  // Array indices 0 to 32
            10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35,  // Array indices 33 to 58
        //  A,  B,  C,  D,  E,  F,  G,  H,  I,  J,  K,  L,  M,  N,  O,  P,  Q,  R,  S,  T,  U,  V,  W,  X,  Y,  Z,  // ASCII codes 65 to 90
        ];
}
