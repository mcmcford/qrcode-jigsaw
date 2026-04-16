import argparse
from pathlib import Path


def scad_string(value):
    escaped = (
        value.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
    )
    return f'"{escaped}"'


def write_scad_file(lines, out_file):
    Path(out_file).write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {out_file}")


def make_qr_data_scad(data, out_file="qr_data.scad", size_mm=100.0, border=4):
    import qrcode

    qr = qrcode.QRCode(
        version=None,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=1,
        border=border,
    )
    qr.add_data(data)
    qr.make(fit=True)

    matrix = qr.get_matrix()
    rows = ["[" + ",".join("1" if cell else "0" for cell in row) + "]" for row in matrix]

    write_scad_file(
        [
            'overlay_mode = "qr";',
            f"overlay_size_mm = {size_mm};",
            f"qr_size_mm = {size_mm};",
            "qr_rows = [",
            "  " + ",\n  ".join(rows),
            "];",
        ],
        out_file,
    )


def make_text_data_scad(
    text,
    out_file="qr_data.scad",
    font="Liberation Sans:style=Bold",
    size_mm=None,
    spacing=1.0,
    line_spacing=1.15,
):
    text_lines = text.splitlines() or [text]
    lines = [
        'overlay_mode = "text";',
        f"overlay_text = {scad_string(text)};",
        "overlay_text_lines = ["
        + ", ".join(scad_string(line) for line in text_lines)
        + "];",
        f"overlay_text_font = {scad_string(font)};",
        f"overlay_text_spacing = {spacing};",
        f"overlay_text_line_spacing = {line_spacing};",
    ]
    if size_mm is not None:
        lines.append(f"overlay_text_size_mm = {size_mm};")

    write_scad_file(lines, out_file)


def build_parser():
    parser = argparse.ArgumentParser(
        description="Generate OpenSCAD overlay data for a jigsaw puzzle."
    )
    parser.add_argument(
        "data",
        help="QR payload or text to emboss onto the puzzle.",
    )
    parser.add_argument(
        "out_file",
        nargs="?",
        default="qr_data.scad",
        help="Output SCAD file path. Defaults to qr_data.scad.",
    )
    parser.add_argument(
        "--mode",
        choices=("qr", "text"),
        default="qr",
        help="Overlay type to generate. Defaults to qr.",
    )
    parser.add_argument(
        "--size-mm",
        type=float,
        default=None,
        help="Overlay size hint. For QR this defaults to 100mm. For text it sets the text size directly.",
    )
    parser.add_argument(
        "--border",
        type=int,
        default=4,
        help="Quiet-zone border size for QR generation.",
    )
    parser.add_argument(
        "--font",
        default="Liberation Sans:style=Bold",
        help="OpenSCAD font descriptor used in text mode.",
    )
    parser.add_argument(
        "--spacing",
        type=float,
        default=1.0,
        help="Character spacing multiplier used in text mode.",
    )
    parser.add_argument(
        "--line-spacing",
        type=float,
        default=1.15,
        help="Line spacing multiplier used in text mode.",
    )
    return parser


if __name__ == "__main__":
    args = build_parser().parse_args()

    if args.mode == "qr":
        make_qr_data_scad(
            args.data,
            out_file=args.out_file,
            size_mm=100.0 if args.size_mm is None else args.size_mm,
            border=args.border,
        )
    else:
        make_text_data_scad(
            args.data,
            out_file=args.out_file,
            font=args.font,
            size_mm=args.size_mm,
            spacing=args.spacing,
            line_spacing=args.line_spacing,
        )
