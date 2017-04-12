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
    enum stopSymbol = bitsStr!"##---###-#-##";

    this() { }

    override BarCode encode(string str)
    {
        auto syms = parseStrToSymbol(str);
        auto chsm = calcCheckSumm(syms);

        BitArray ret;

        foreach (s; syms)
            ret.addBits(s.mask);

        ret.addBits(chsm.mask);
        ret.addBits(stopSymbol);
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
    Sym(   ` `,    ` `,   "00", bitsStr!"##-##--##--"),
    Sym(   `!`,    `!`,   "01", bitsStr!"##--##-##--"),
    Sym(   `"`,    `"`,   "02", bitsStr!"##--##--##-"),
    Sym(   `#`,    `#`,   "03", bitsStr!"#--#--##---"),
    Sym(   `$`,    `$`,   "04", bitsStr!"#--#---##--"),
    Sym(   `%`,    `%`,   "05", bitsStr!"#---#--##--"),
    Sym(   `&`,    `&`,   "06", bitsStr!"#--##--#---"),
    Sym(   `'`,    `'`,   "07", bitsStr!"#--##---#--"),
    Sym(   `(`,    `(`,   "08", bitsStr!"#---##--#--"),
    Sym(   `)`,    `)`,   "09", bitsStr!"##--#--#---"),
    Sym(   `*`,    `*`,   "10", bitsStr!"##--#---#--"),
    Sym(   `+`,    `+`,   "11", bitsStr!"##---#--#--"),
    Sym(   `,`,    `,`,   "12", bitsStr!"#-##--###--"),
    Sym(   `-`,    `-`,   "13", bitsStr!"#--##-###--"),
    Sym(   `.`,    `.`,   "14", bitsStr!"#--##--###-"),
    Sym(   `/`,    `/`,   "15", bitsStr!"#-###--##--"),
    Sym(   `0`,    `0`,   "16", bitsStr!"#--###-##--"),
    Sym(   `1`,    `1`,   "17", bitsStr!"#--###--##-"),
    Sym(   `2`,    `2`,   "18", bitsStr!"##--###--#-"),
    Sym(   `3`,    `3`,   "19", bitsStr!"##--#-###--"),
    Sym(   `4`,    `4`,   "20", bitsStr!"##--#--###-"),
    Sym(   `5`,    `5`,   "21", bitsStr!"##-###--#--"),
    Sym(   `6`,    `6`,   "22", bitsStr!"##--###-#--"),
    Sym(   `7`,    `7`,   "23", bitsStr!"###-##-###-"),
    Sym(   `8`,    `8`,   "24", bitsStr!"###-#--##--"),
    Sym(   `9`,    `9`,   "25", bitsStr!"###--#-##--"),
    Sym(   `:`,    `:`,   "26", bitsStr!"###--#--##-"),
    Sym(   `;`,    `;`,   "27", bitsStr!"###-##--#--"),
    Sym(   `<`,    `<`,   "28", bitsStr!"###--##-#--"),
    Sym(   `=`,    `=`,   "29", bitsStr!"###--##--#-"),
    Sym(   `>`,    `>`,   "30", bitsStr!"##-##-##---"),
    Sym(   `?`,    `?`,   "31", bitsStr!"##-##---##-"),
    Sym(   `@`,    `@`,   "32", bitsStr!"##---##-##-"),
    Sym(   `A`,    `A`,   "33", bitsStr!"#-#---##---"),
    Sym(   `B`,    `B`,   "34", bitsStr!"#---#-##---"),
    Sym(   `C`,    `C`,   "35", bitsStr!"#---#---##-"),
    Sym(   `D`,    `D`,   "36", bitsStr!"#-##---#---"),
    Sym(   `E`,    `E`,   "37", bitsStr!"#---##-#---"),
    Sym(   `F`,    `F`,   "38", bitsStr!"#---##---#-"),

    Sym(   `G`,    `G`,   "39", bitsStr!"##-#---#---"),
    Sym(   `H`,    `H`,   "40", bitsStr!"##---#-#---"),
    Sym(   `I`,    `I`,   "41", bitsStr!"##---#---#-"),
    Sym(   `J`,    `J`,   "42", bitsStr!"#-##-###---"),
    Sym(   `K`,    `K`,   "43", bitsStr!"#-##---###-"),
    Sym(   `L`,    `L`,   "44", bitsStr!"#---##-###-"),
    Sym(   `M`,    `M`,   "45", bitsStr!"#-###-##---"),
    Sym(   `N`,    `N`,   "46", bitsStr!"#-###---##-"),
    Sym(   `O`,    `O`,   "47", bitsStr!"#---###-##-"),
    Sym(   `P`,    `P`,   "48", bitsStr!"###-###-##-"),
    Sym(   `Q`,    `Q`,   "49", bitsStr!"##-#---###-"),
    Sym(   `R`,    `R`,   "50", bitsStr!"##---#-###-"),
    Sym(   `S`,    `S`,   "51", bitsStr!"##-###-#---"),
    Sym(   `T`,    `T`,   "52", bitsStr!"##-###---#-"),
    Sym(   `U`,    `U`,   "53", bitsStr!"##-###-###-"),
    Sym(   `V`,    `V`,   "54", bitsStr!"###-#-##---"),
    Sym(   `W`,    `W`,   "55", bitsStr!"###-#---##-"),
    Sym(   `X`,    `X`,   "56", bitsStr!"###---#-##-"),
    Sym(   `Y`,    `Y`,   "57", bitsStr!"###-##-#---"),
    Sym(   `Z`,    `Z`,   "58", bitsStr!"###-##---#-"),
    Sym(   `[`,    `[`,   "59", bitsStr!"###---##-#-"),
    Sym(   `\`,    `\`,   "60", bitsStr!"###-####-#-"),
    Sym(   `]`,    `]`,   "61", bitsStr!"##--#----#-"),
    Sym(   `^`,    `^`,   "62", bitsStr!"####---#-#-"),
    Sym(   `_`,    `_`,   "63", bitsStr!"#-#--##----"),
    Sym(   NUL,    "`",   "64", bitsStr!"#-#----##--"),
    Sym(   SOH,    "a",   "65", bitsStr!"#--#-##----"),
    Sym(   STX,    "b",   "66", bitsStr!"#--#----##-"),
    Sym(   ETX,    "c",   "67", bitsStr!"#----#-##--"),
    Sym(   EOT,    "d",   "68", bitsStr!"#----#--##-"),
    Sym(   ENQ,    "e",   "69", bitsStr!"#-##--#----"),
    Sym(   ACK,    "f",   "70", bitsStr!"#-##----#--"),
    Sym(   BEL,    "g",   "71", bitsStr!"#--##-#----"),
    Sym(    BS,    "h",   "72", bitsStr!"#--##----#-"),
    Sym(    HT,    "i",   "73", bitsStr!"#----##-#--"),
    Sym(    LF,    "j",   "74", bitsStr!"#----##--#-"),
    Sym(    VT,    "k",   "75", bitsStr!"##----#--#-"),
    Sym(    FF,    "l",   "76", bitsStr!"##--#-#----"),
    Sym(    CR,    "m",   "77", bitsStr!"####-###-#-"),
    Sym(    SO,    "n",   "78", bitsStr!"##----#-#--"),
    Sym(    SI,    "o",   "79", bitsStr!"#---####-#-"),

    Sym(   DLE,    "p",   "80", bitsStr!"#-#--####--"),
    Sym(   DC1,    "q",   "81", bitsStr!"#--#-####--"),
    Sym(   DC2,    "r",   "82", bitsStr!"#--#--####-"),
    Sym(   DC3,    "s",   "83", bitsStr!"#-####--#--"),
    Sym(   DC4,    "t",   "84", bitsStr!"#--####-#--"),
    Sym(   NAK,    "u",   "85", bitsStr!"#--####--#-"),
    Sym(   SYN,    "v",   "86", bitsStr!"####-#--#--"),
    Sym(   ETB,    "w",   "87", bitsStr!"####--#-#--"),
    Sym(   CAN,    "x",   "88", bitsStr!"####--#--#-"),
    Sym(    EM,    "y",   "89", bitsStr!"##-##-####-"),
    Sym(   SUB,    "z",   "90", bitsStr!"##-####-##-"),
    Sym(   ESC,    "{",   "91", bitsStr!"####-##-##-"),
    Sym(    FS,    "|",   "92", bitsStr!"#-#-####---"),
    Sym(    GS,    "}",   "93", bitsStr!"#-#---####-"),
    Sym(    RS,    "~",   "94", bitsStr!"#---#-####-"),
    Sym(    US,    DEL,   "95", bitsStr!"#-####-#---"),
    Sym(  FNC3,   FNC3,   "96", bitsStr!"#-####---#-"),
    Sym(  FNC2,   FNC2,   "97", bitsStr!"####-#-#---"),
    Sym( Shift,  Shift,   "98", bitsStr!"####-#---#-"),
    Sym(CODE_C, CODE_C,   "99", bitsStr!"#-###-####-"),
    Sym(CODE_B,   FNC4, CODE_B, bitsStr!"#-####-###-"),
    Sym(  FNC4, CODE_A, CODE_A, bitsStr!"###-#-####-"),
    Sym(  FNC1,   FNC1,   FNC1, bitsStr!"####-#-###-"),
    Sym(StartA, StartA, StartA, bitsStr!"##-#----#--"),
    Sym(StartB, StartB, StartB, bitsStr!"##-#--#----"),
    Sym(StartC, StartC, StartC, bitsStr!"##-#--###--"),
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
