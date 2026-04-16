# qrcode-jigsaw

Generate a jigsaw puzzle with either a QR-code overlay or a text overlay using Python and OpenSCAD.

## What It Does

`main.py` generates a SCAD data file for either a QR code or plain text. Then, `jigsaw.scad` places that overlay onto a simple jigsaw puzzle template, which you can render and export as an STL file for 3D printing.

## Requirements

- Python 3
- `qrcode` Python package for QR mode
- OpenSCAD

## Quick Start

```bash
pip install qrcode
python main.py "https://example.com"
```

Then open `jigsaw.scad` in OpenSCAD and render/export the model.

For text instead of a QR code:

```bash
python main.py --mode text "HELLO WORLD"
```

You can also tune the text appearance from the generator:

```bash
python main.py --mode text --font "Liberation Serif:style=Bold" --size-mm 28 --spacing 1.1 "HELLO WORLD"
```

## SCAD Variables

You can tweak these values near the top of `jigsaw.scad`:

- `rows`, `cols` - number of puzzle pieces across and down (it doesn't account for non-square puzzles, so keep them the same for best results or improve the code!)
- `piece_w_mm`, `piece_h_mm` - size of each puzzle piece
- `tab_r_mm` - size of the jigsaw tabs
- `thick_mm` - base thickness of each piece
- `gap_mm` - spacing between pieces in the layout
- `qr_relief_mm` - height of the raised overlay pattern
- `top_color`, `qr_color` - preview colors in OpenSCAD
- `arc_n` - smoothness of the tab curves

If `qr_data.scad` is in text mode, it can also define:

- `overlay_text_font` - OpenSCAD font name used for the text overlay
- `overlay_text_size_mm` - text size in mm
- `overlay_text_spacing` - text character spacing multiplier
- `overlay_text_margin_mm` - padding used by auto-fit text scaling when no explicit text size is set

## Files

- `main.py` - generates QR or text overlay data for OpenSCAD
- `jigsaw.scad` - builds the jigsaw model
- `qr_data.scad` - generated file used by OpenSCAD