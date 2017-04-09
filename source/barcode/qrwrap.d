module barcode.qrwrap;

import std.exception;
import barcode.qr;
import barcode.types;

class Qr : BarCodeEncoder
{
    ECL ecl;
    uint minVer, maxVer;

    this(ECL ecl=ECL.medium, uint minVer=1, uint maxVer=40)
    {
        enforce(minVer >= 1 && minVer <= maxVer && maxVer <= 40,
                "wrong min/max version");

        this.ecl = ecl;
        this.minVer = minVer;
        this.maxVer = maxVer;
    }

    BarCode encode(string str)
    {
        auto segs = QrSegment.makeSegments(str);
        auto qrcode = QrCode.encodeSegments(segs, ecl, minVer, maxVer, -1, true);
        return BarCode(qrcode.size, qrcode.modules, "qrcode");
    }
}
