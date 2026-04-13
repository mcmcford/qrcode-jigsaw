# make_qr_data_scad.py
import sys
from pathlib import Path
import qrcode


def make_qr_data_scad(data, out_file="qr_data.scad", size_mm=100.0, border=4):
    qr = qrcode.QRCode(
        version=None,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=1,
        border=border,
    )
    qr.add_data(data)
    qr.make(fit=True)

    matrix = qr.get_matrix()

    rows = []
    for row in matrix:
        rows.append("[" + ",".join("1" if cell else "0" for cell in row) + "]")

    content = (
        f"qr_size_mm = {size_mm};\n" f"qr_rows = [\n  " + ",\n  ".join(rows) + "\n];\n"
    )

    Path(out_file).write_text(content, encoding="utf-8")
    print(f"Wrote {out_file}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python make_qr_data_scad.py 'your text or URL' [output.scad]")
        raise SystemExit(1)

    data = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else "qr_data.scad"
    make_qr_data_scad(data, out_file=out)
