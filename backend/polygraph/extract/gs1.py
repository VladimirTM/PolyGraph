"""GS1 DataMatrix pentru identificatorii 01, 17, 10 și 21."""

import calendar
import re
from datetime import date
from io import BytesIO

import zxingcpp
from PIL import Image

GS = "\x1d"
FIELDS = {"01": "gtin", "17": "expiry", "10": "batch", "21": "serial"}


def valid_gtin(value: str) -> bool:
    return (
        bool(re.fullmatch(r"[0-9]{14}", value))
        and sum(int(digit) * (1 if i % 2 == 0 else 3) for i, digit in enumerate(reversed(value))) % 10 == 0
    )


def parse_gs1(raw: str) -> dict[str, str | None]:
    raw = raw.strip(" \r\n").removeprefix("]d2")
    result = dict.fromkeys(FIELDS.values())
    while raw:
        raw = raw.lstrip(GS)
        if not raw:
            break
        ai, raw = raw[:2], raw[2:]
        if ai not in FIELDS or result[FIELDS[ai]] is not None:
            raise ValueError("not_gs1")
        if ai in ("01", "17"):
            length = 14 if ai == "01" else 6
            value, raw = raw[:length], raw[length:]
            if not re.fullmatch(rf"[0-9]{{{length}}}", value):
                raise ValueError("not_gs1")
            if ai == "01" and not valid_gtin(value):
                raise ValueError("invalid_gtin_check_digit")
            if ai == "17":
                year, month, day = (int(value[i : i + 2]) for i in (0, 2, 4))
                year += 2000
                if not 1 <= month <= 12:
                    raise ValueError("invalid_expiry")
                value = date(year, month, day or calendar.monthrange(year, month)[1]).isoformat()
        else:
            value, _, raw = raw.partition(GS)
            if not re.fullmatch(r"[!-~]{1,20}", value):
                raise ValueError("not_gs1")
        result[FIELDS[ai]] = value
    if result["gtin"] is None:
        raise ValueError("not_gs1")
    return result


def decode_datamatrix(image: bytes) -> dict[str, str | None] | None:
    try:
        with Image.open(BytesIO(image)) as pixels:
            if pixels.width * pixels.height > 16_000_000:
                return None
            codes = zxingcpp.read_barcodes(pixels.convert("L"), formats=zxingcpp.BarcodeFormat.DataMatrix)
    except (OSError, ValueError, Image.DecompressionBombError):
        return None
    for code in codes:
        try:
            return parse_gs1(code.bytes.decode("ascii"))
        except ValueError:
            continue
    return None
