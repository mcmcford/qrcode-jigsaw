# qrcode-jigsaw

Generate a QR-code jigsaw puzzle with Python and OpenSCAD.

## What It Does

`main.py` turns a string or URL into a QR Code in the form of SCAD, you can generate one and see the array of 1s and 0s that represent the code. Then, `jigsaw.scad` places that data onto a fairly simple jigsaw puzzle template, which you can then render and export as an STL file for 3D printing. The result is a physical jigsaw puzzle that, when assembled, forms a QR code that can be scanned with a camera.

## Requirements

- Python 3
- `qrcode` Python package
- OpenSCAD

## Quick Start

```bash
pip install qrcode
python main.py "https://example.com"
```

Then open `jigsaw.scad` in OpenSCAD and render/export the model.

## SCAD Variables

You can tweak these values near the top of `jigsaw.scad`:

- `rows`, `cols` - number of puzzle pieces across and down (it doesn't account for non-square puzzles, so keep them the same for best results or improve the code!)
- `piece_w_mm`, `piece_h_mm` - size of each puzzle piece
- `tab_r_mm` - size of the jigsaw tabs
- `thick_mm` - base thickness of each piece
- `gap_mm` - spacing between pieces in the layout
- `qr_relief_mm` - height of the raised QR pattern
- `top_color`, `qr_color` - preview colors in OpenSCAD
- `arc_n` - smoothness of the tab curves

## Files

- `main.py` - generates QR data for OpenSCAD
- `jigsaw.scad` - builds the jigsaw model
- `qr_data.scad` - generated file used by OpenSCAD