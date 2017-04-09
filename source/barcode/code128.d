///
module barcode.code128;

import std.experimental.logger;

import std.exception;
import std.string;
import std.range;
import std.array;
import std.typecons : tuple;

import barcode.types;
import barcode.util;

///
class Code128 : BarCodeEncoder
{
    enum whiteSpace = bits!"----------";
    enum stopSymbol = bits!"##---###-#-##";

    this() { }

    override BarCode encode(string str)
    {
        auto syms = parseStrToSymbol(str);
        auto chsm = calcCheckSumm(syms);

        BitArray ret;
        ret.addBits(whiteSpace);

        foreach (s; syms)
            ret.addBits(s.mask);

        ret.addBits(chsm.mask);
        ret.addBits(stopSymbol);
        ret.addBits(whiteSpace);
        return BarCode(ret.length, ret, "code128");
    }
}

private:

struct Sym
{
    size_t num;
    string A, B, C;
    Bits!ushort mask;

    this(string a, string b, string c, Bits!ushort bts) pure
    {
        A = a;
        B = b;
        C = c;
        mask = bts;
    }
}

Sym symByNum(size_t num) { return src_table[num]; }

Sym symByA(const(char)[] ch...) { return src_table[sym_by_a[ch.idup]]; }
Sym symByB(const(char)[] ch...) { return src_table[sym_by_b[ch.idup]]; }
Sym symByC(const(char)[] ch...) { return src_table[sym_by_c[ch.idup]]; }

unittest
{
    assert(symByA("E") == symByB("E"));
    char[] tmp = ['E'];
    assert(symByB(tmp) == symByB("E"));
}

enum size_t[string] sym_by_a = src_table.getDict!((i,v) => tuple(v.A, i));
enum size_t[string] sym_by_b = src_table.getDict!((i,v) => tuple(v.B, i));
enum size_t[string] sym_by_c = src_table.getDict!((i,v) => tuple(v.C, i));

Sym[] parseStrToSymbol(string str, int state=0)
{
    import std.algorithm;
    import std.ascii;

    enforce(0 <= state && state <= 3, "unknown last state");

    Sym[] setA()
    {
        auto ret = [0: [symByA(StartA)],
                    1: [/+ already in A mode +/],
                    2: [symByB(CODE_A)],
                    3: [symByC(CODE_A)]][state];
        state = 1;
        return ret;
    }

    Sym[] setB()
    {
        auto ret = [0: [symByA(StartB)],
                    1: [symByA(CODE_B)],
                    2: [/+ already in B mode +/],
                    3: [symByC(CODE_B)]][state];
        state = 2;
        return ret;
    }

    Sym[] setC()
    {
        auto ret = [0: [symByA(StartC)],
                    1: [symByA(CODE_C)],
                    2: [symByB(CODE_C)],
                    3: [/+ already in C +/]][state];
        state = 3;
        return ret;
    }

    Sym[] encA(const(char)[] ch...) { return setA ~ symByA(ch); }
    Sym[] encB(const(char)[] ch...) { return setB ~ symByB(ch); }
    Sym[] encC(const(char)[] ch...) { return setC ~ symByC(ch); }

    Sym[] encState(const(char)[] ch...)
    {
        if (state == 1) return [symByA(ch)];
        else return setB ~ symByB(ch);
    }

    Sym[] encShift(const(char)[] ch...)
    {
             if (state == 1) return [symByA(Shift)] ~ symByB(ch);
        else if (state == 2) return [symByB(Shift)] ~ symByA(ch);
        else assert(0, "logic error in code");
    }

    Sym[] encSwitch(const(char)[] ch...)
    { return [1: encB(ch), 2: encA(ch)][state]; }

    bool isOtherSpec(const(char)[] ch...)
    {
             if (state == 1) return SpecB.canFind(ch);
        else if (state == 2) return SpecA.canFind(ch);
        else return false;
    }

    bool isSpec(const(char)[] ch...)
    {
             if (state == 1) return SpecA.canFind(ch);
        else if (state == 2) return SpecB.canFind(ch);
        else return false;
    }

    Sym[] ret;

    while (str.length)
    {
        auto dc = str.digitsSequenceCount;
        if (dc >= 4 && (state == 0 || (dc % 2)==0))
        {
            while (str.digitsSequenceCount >= 2)
            {
                ret ~= encC(str[0..2]);
                str = str[2..$];
            }
        }
        else
        {
            auto ch = str[0];
            auto sAc = str.specACount, sBc = str.specBCount;
                 if (!sAc && !sBc) ret ~= encState(ch);
            else if ( sAc && !sBc) ret ~= encA(ch);
            else if ( sBc && !sAc) ret ~= encB(ch);
            else if (str.length >= 2) // if str.length == 1 one of first 3 statements are was true
            {
                if (isOtherSpec(ch))
                {
                    if (isSpec(str[1])) ret ~= encShift(ch);
                    else ret ~= encSwitch(ch);
                }
                else
                    ret ~= encState(ch);
            }
            else assert(0, "logic error in code");

            str = str[1..$];
        }
    }

    return ret;
}

unittest
{
    import std.algorithm : equal;
    import std.conv : text;

    {
        auto g = parseStrToSymbol("EIA50-1234-123456");
        auto m = getSymbol(StartB, "E", "I", "A", "5", "0",
                    "-", CODE_C, "12", "34",
                    CODE_B, "-", CODE_C, "12", "34", "56");
        assert(equal(m, g));
    }
    {
        auto g = parseStrToSymbol("EIA50-12345-1234567");
        auto m = getSymbol(StartB, "E", "I", "A", "5", "0",
                    "-", "1", CODE_C, "23", "45",
                    CODE_B, "-", "1", CODE_C, "23", "45", "67");
        assert(equal(m, g), text("\n", m, "\n", g));
    }
    {
        auto g = parseStrToSymbol("oneOFthis\0ABC");
        auto m = getSymbol(StartB, "o", "n", "e", "O", "F", "t", "h", "i", "s",
                           CODE_A, NUL, "A", "B", "C");
        assert(equal(m, g), text("\n", m, "\n", g));
    }
}

size_t digitsSequenceCount(string str)
{
    import std.ascii;
    foreach (i; 0 .. str.length)
        if (!str[i].isDigit)
            return i;
    return str.length;
}

unittest
{
    assert("0123".digitsSequenceCount == 4);
    assert("01ab23".digitsSequenceCount == 2);
    assert("0431ab23".digitsSequenceCount == 4);
    assert("ab0431ab23".digitsSequenceCount == 0);
}

size_t specACount(string str)
{
    import std.algorithm;
    size_t ret;
    foreach (i; 0 .. str.length)
        if (SpecA.canFind(""~str[i]))
            ret++;
    return ret;
}

size_t specBCount(string str)
{
    import std.algorithm;
    size_t ret;
    foreach (i; 0 .. str.length)
        if (SpecB.canFind(""~str[i]))
            ret++;
    return ret;
}

Sym calcCheckSumm(Sym[] symbol)
{
    enforce(symbol.length >= 1);

    size_t tmp = symbol[0].num;
    foreach(i, sym; symbol)
        tmp += sym.num * i; // first in tmp yet
    tmp %= 103;
    return symByNum(tmp);
}

unittest
{
    auto arr = [StartB, "A", "I", "M", CODE_C, "12", "34"];
    assert(calcCheckSumm(getSymbol(arr)).num == 87);
}

Sym[] getSymbol(string[] arr...)
{
    enum State { A,B,C }
    State curr;
    switch (arr[0])
    {
        case StartA: curr = State.A; break;
        case StartB: curr = State.B; break;
        case StartC: curr = State.C; break;
        default: throw new Exception("arr mush starts from StartX symbol");
    }
    bool shift;
    Sym symByCurr(string v)
    {
        final switch (curr)
        {
            case State.A: return shift ? symByB(v) : symByA(v);
            case State.B: return shift ? symByA(v) : symByB(v);
            case State.C: return symByC(v);
        }
    }

    Sym[] ret = [symByA(arr[0])];

    foreach (v; arr[1..$])
    {
        ret ~= symByCurr(v);
        shift = false;
        switch (v)
        {
            case CODE_A: curr = State.A; break;
            case CODE_B: curr = State.B; break;
            case CODE_C: curr = State.C; break;
            case Shift: shift = true; break;
            default: break;
        }
    }

    return ret;
}

auto setNum(Sym[] tbl) { foreach (i, ref v; tbl) v.num = i; return tbl; }

enum src_table =
[   // used origin mask: # (black), - (white)
    Sym(   ` `,    ` `,   "00", bits!"##-##--##--"),
    Sym(   `!`,    `!`,   "01", bits!"##--##-##--"),
    Sym(   `"`,    `"`,   "02", bits!"##--##--##-"),
    Sym(   `#`,    `#`,   "03", bits!"#--#--##---"),
    Sym(   `$`,    `$`,   "04", bits!"#--#---##--"),
    Sym(   `%`,    `%`,   "05", bits!"#---#--##--"),
    Sym(   `&`,    `&`,   "06", bits!"#--##--#---"),
    Sym(   `'`,    `'`,   "07", bits!"#--##---#--"),
    Sym(   `(`,    `(`,   "08", bits!"#---##--#--"),
    Sym(   `)`,    `)`,   "09", bits!"##--#--#---"),
    Sym(   `*`,    `*`,   "10", bits!"##--#---#--"),
    Sym(   `+`,    `+`,   "11", bits!"##---#--#--"),
    Sym(   `,`,    `,`,   "12", bits!"#-##--###--"),
    Sym(   `-`,    `-`,   "13", bits!"#--##-###--"),
    Sym(   `.`,    `.`,   "14", bits!"#--##--###-"),
    Sym(   `/`,    `/`,   "15", bits!"#-###--##--"),
    Sym(   `0`,    `0`,   "16", bits!"#--###-##--"),
    Sym(   `1`,    `1`,   "17", bits!"#--###--##-"),
    Sym(   `2`,    `2`,   "18", bits!"##--###--#-"),
    Sym(   `3`,    `3`,   "19", bits!"##--#-###--"),
    Sym(   `4`,    `4`,   "20", bits!"##--#--###-"),
    Sym(   `5`,    `5`,   "21", bits!"##-###--#--"),
    Sym(   `6`,    `6`,   "22", bits!"##--###-#--"),
    Sym(   `7`,    `7`,   "23", bits!"###-##-###-"),
    Sym(   `8`,    `8`,   "24", bits!"###-#--##--"),
    Sym(   `9`,    `9`,   "25", bits!"###--#-##--"),
    Sym(   `:`,    `:`,   "26", bits!"###--#--##-"),
    Sym(   `;`,    `;`,   "27", bits!"###-##--#--"),
    Sym(   `<`,    `<`,   "28", bits!"###--##-#--"),
    Sym(   `=`,    `=`,   "29", bits!"###--##--#-"),
    Sym(   `>`,    `>`,   "30", bits!"##-##-##---"),
    Sym(   `?`,    `?`,   "31", bits!"##-##---##-"),
    Sym(   `@`,    `@`,   "32", bits!"##---##-##-"),
    Sym(   `A`,    `A`,   "33", bits!"#-#---##---"),
    Sym(   `B`,    `B`,   "34", bits!"#---#-##---"),
    Sym(   `C`,    `C`,   "35", bits!"#---#---##-"),
    Sym(   `D`,    `D`,   "36", bits!"#-##---#---"),
    Sym(   `E`,    `E`,   "37", bits!"#---##-#---"),
    Sym(   `F`,    `F`,   "38", bits!"#---##---#-"),

    Sym(   `G`,    `G`,   "39", bits!"##-#---#---"),
    Sym(   `H`,    `H`,   "40", bits!"##---#-#---"),
    Sym(   `I`,    `I`,   "41", bits!"##---#---#-"),
    Sym(   `J`,    `J`,   "42", bits!"#-##-###---"),
    Sym(   `K`,    `K`,   "43", bits!"#-##---###-"),
    Sym(   `L`,    `L`,   "44", bits!"#---##-###-"),
    Sym(   `M`,    `M`,   "45", bits!"#-###-##---"),
    Sym(   `N`,    `N`,   "46", bits!"#-###---##-"),
    Sym(   `O`,    `O`,   "47", bits!"#---###-##-"),
    Sym(   `P`,    `P`,   "48", bits!"###-###-##-"),
    Sym(   `Q`,    `Q`,   "49", bits!"##-#---###-"),
    Sym(   `R`,    `R`,   "50", bits!"##---#-###-"),
    Sym(   `S`,    `S`,   "51", bits!"##-###-#---"),
    Sym(   `T`,    `T`,   "52", bits!"##-###---#-"),
    Sym(   `U`,    `U`,   "53", bits!"##-###-###-"),
    Sym(   `V`,    `V`,   "54", bits!"###-#-##---"),
    Sym(   `W`,    `W`,   "55", bits!"###-#---##-"),
    Sym(   `X`,    `X`,   "56", bits!"###---#-##-"),
    Sym(   `Y`,    `Y`,   "57", bits!"###-##-#---"),
    Sym(   `Z`,    `Z`,   "58", bits!"###-##---#-"),
    Sym(   `[`,    `[`,   "59", bits!"###---##-#-"),
    Sym(   `\`,    `\`,   "60", bits!"###-####-#-"),
    Sym(   `]`,    `]`,   "61", bits!"##--#----#-"),
    Sym(   `^`,    `^`,   "62", bits!"####---#-#-"),
    Sym(   `_`,    `_`,   "63", bits!"#-#--##----"),
    Sym(   NUL,    "`",   "64", bits!"#-#----##--"),
    Sym(   SOH,    "a",   "65", bits!"#--#-##----"),
    Sym(   STX,    "b",   "66", bits!"#--#----##-"),
    Sym(   ETX,    "c",   "67", bits!"#----#-##--"),
    Sym(   EOT,    "d",   "68", bits!"#----#--##-"),
    Sym(   ENQ,    "e",   "69", bits!"#-##--#----"),
    Sym(   ACK,    "f",   "70", bits!"#-##----#--"),
    Sym(   BEL,    "g",   "71", bits!"#--##-#----"),
    Sym(    BS,    "h",   "72", bits!"#--##----#-"),
    Sym(    HT,    "i",   "73", bits!"#----##-#--"),
    Sym(    LF,    "j",   "74", bits!"#----##--#-"),
    Sym(    VT,    "k",   "75", bits!"##----#--#-"),
    Sym(    FF,    "l",   "76", bits!"##--#-#----"),
    Sym(    CR,    "m",   "77", bits!"####-###-#-"),
    Sym(    SO,    "n",   "78", bits!"##----#-#--"),
    Sym(    SI,    "o",   "79", bits!"#---####-#-"),

    Sym(   DLE,    "p",   "80", bits!"#-#--####--"),
    Sym(   DC1,    "q",   "81", bits!"#--#-####--"),
    Sym(   DC2,    "r",   "82", bits!"#--#--####-"),
    Sym(   DC3,    "s",   "83", bits!"#-####--#--"),
    Sym(   DC4,    "t",   "84", bits!"#--####-#--"),
    Sym(   NAK,    "u",   "85", bits!"#--####--#-"),
    Sym(   SYN,    "v",   "86", bits!"####-#--#--"),
    Sym(   ETB,    "w",   "87", bits!"####--#-#--"),
    Sym(   CAN,    "x",   "88", bits!"####--#--#-"),
    Sym(    EM,    "y",   "89", bits!"##-##-####-"),
    Sym(   SUB,    "z",   "90", bits!"##-####-##-"),
    Sym(   ESC,    "{",   "91", bits!"####-##-##-"),
    Sym(    FS,    "|",   "92", bits!"#-#-####---"),
    Sym(    GS,    "}",   "93", bits!"#-#---####-"),
    Sym(    RS,    "~",   "94", bits!"#---#-####-"),
    Sym(    US,    DEL,   "95", bits!"#-####-#---"),
    Sym(  FNC3,   FNC3,   "96", bits!"#-####---#-"),
    Sym(  FNC2,   FNC2,   "97", bits!"####-#-#---"),
    Sym( Shift,  Shift,   "98", bits!"####-#---#-"),
    Sym(CODE_C, CODE_C,   "99", bits!"#-###-####-"),
    Sym(CODE_B,   FNC4, CODE_B, bits!"#-####-###-"),
    Sym(  FNC4, CODE_A, CODE_A, bits!"###-#-####-"),
    Sym(  FNC1,   FNC1,   FNC1, bits!"####-#-###-"),
    Sym(StartA, StartA, StartA, bits!"##-#----#--"),
    Sym(StartB, StartB, StartB, bits!"##-#--#----"),
    Sym(StartC, StartC, StartC, bits!"##-#--###--"),
].setNum;

unittest
{
    assert(symByB(StartB).num == 104);
    assert(symByB("A").num == 33);
    assert(symByB("I").num == 41);
    assert(symByB("M").num == 45);
    assert(symByB(CODE_C).num == 99);
    assert(symByC("12").num == 12);
    assert(symByC("34").num == 34);

    assert(symByB(CODE_A).num == 101);

    assert(symByA(FS) == symByB("|"));
    assert(symByA(FS) == symByC("92"));
}

string chSym(ubyte v) { return "" ~ cast(char)(v); }

enum NUL = chSym( 0);
enum SOH = chSym( 1);
enum STX = chSym( 2);
enum ETX = chSym( 3);
enum EOT = chSym( 4);
enum ENQ = chSym( 5);
enum ACK = chSym( 6);
enum BEL = chSym( 7);
enum  BS = chSym( 8);
enum  HT = chSym( 9);
enum  LF = chSym(10);
enum  VT = chSym(11);
enum  FF = chSym(12);
enum  CR = chSym(13);
enum  SO = chSym(14);
enum  SI = chSym(15);

enum DLE = chSym(16);
enum DC1 = chSym(17);
enum DC2 = chSym(18);
enum DC3 = chSym(19);
enum DC4 = chSym(20);
enum NAK = chSym(21);
enum SYN = chSym(22);
enum ETB = chSym(23);
enum CAN = chSym(24);
enum  EM = chSym(25);
enum SUB = chSym(26);
enum ESC = chSym(27);
enum  FS = chSym(28);
enum  GS = chSym(29);
enum  RS = chSym(30);
enum  US = chSym(31);
enum DEL = chSym(127);

enum   FNC1 = NUL ~ "!FNC1";
enum   FNC2 = NUL ~ "!FNC2";
enum   FNC3 = NUL ~ "!FNC3";
enum   FNC4 = NUL ~ "!FNC4";
enum  Shift = NUL ~ "!Shift";
enum CODE_A = NUL ~ "!CODE_A";
enum CODE_B = NUL ~ "!CODE_B";
enum CODE_C = NUL ~ "!CODE_C";
enum StartA = NUL ~ "!StartA";
enum StartB = NUL ~ "!StartB";
enum StartC = NUL ~ "!StartC";

enum SpecA = [ NUL, SOH, STX, ETX, EOT, ENQ, ACK, BEL, BS, HT, LF, VT, FF,
               CR, SO, SI, DLE, DC1, DC2, DC3, DC4, NAK, SYN, ETB, CAN,
               EM, SUB, ESC, FS, GS, RS, US ];

enum SpecB = ["`", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l",
              "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y",
              "z", "{", "|", "}", "~", DEL];
