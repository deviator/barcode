//
module barcode.qr.ecl;

// Error correction level
struct ECL
{
    ///
    enum      low = ECL(0,1),
           medium = ECL(1,0),
         quartile = ECL(2,3),
             high = ECL(3,2);

    ///
    int ord, formatBits;

    ///
    alias ord this;
}

///
unittest
{
    auto ecl = ECL.medium;
    assert ([7,9,8][ecl] == 9);
    assert (ecl.formatBits == 0);
}
