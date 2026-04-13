// Requires qr_data.scad in the same folder.
// qr_data.scad must define:
//   qr_size_mm = ...;
//   qr_rows = [...];
// that is all handled by main.py, so you can just run that to generate qr_data.scad before rendering this file.

include <qr_data.scad>;

rows = 4;
cols = 4;

piece_w_mm = 40;
piece_h_mm = 40;
tab_r_mm   = 8;
thick_mm   = 4;
gap_mm     = 5;

qr_relief_mm = 2;
top_color     = [0.85, 0.85, 0.85];
qr_color      = [0.10, 0.10, 0.10];

arc_n = 16;

puzzle_w_mm = cols * piece_w_mm + (cols - 1) * gap_mm;
puzzle_h_mm = rows * piece_h_mm + (rows - 1) * gap_mm;

qr_unit_mm = qr_size_mm / len(qr_rows);

function arc_mid(cx, cy, r, a1, a2, n=arc_n) =
    [for (i = [1 : n - 1])
        [cx + r * cos(a1 + (a2 - a1) * i / n),
         cy + r * sin(a1 + (a2 - a1) * i / n)]
    ];

function edge_bottom(x0, x1, y, sign, d, n=arc_n) =
    let(cx = (x0 + x1) / 2)
    sign == 0
        ? [[x1, y]]
        : concat(
            [[cx - d, y]],
            arc_mid(cx, y, d, 180, sign > 0 ? 360 : 0, n),
            [[cx + d, y], [x1, y]]
          );

function edge_right(x, y0, y1, sign, d, n=arc_n) =
    let(cy = (y0 + y1) / 2)
    sign == 0
        ? [[x, y1]]
        : concat(
            [[x, cy - d]],
            arc_mid(x, cy, d, 270, sign > 0 ? 450 : 90, n),
            [[x, cy + d], [x, y1]]
          );

function edge_top(x0, x1, y, sign, d, n=arc_n) =
    let(cx = (x0 + x1) / 2)
    sign == 0
        ? [[x0, y]]
        : concat(
            [[cx + d, y]],
            arc_mid(cx, y, d, 0, sign > 0 ? 180 : -180, n),
            [[cx - d, y], [x0, y]]
          );

function edge_left(x, y0, y1, sign, d, n=arc_n) =
    let(cy = (y0 + y1) / 2)
    sign == 0
        ? [[x, y0]]
        : concat(
            [[x, cy + d]],
            arc_mid(x, cy, d, 90, sign > 0 ? 270 : -90, n),
            [[x, cy - d], [x, y0]]
          );

function tab_sign(r, c) = ((r + c) % 2 == 0) ? 1 : -1;

function piece_pts(x, y, w, h, b, r, t, l, d, n=arc_n) =
    concat(
        [[x, y]],
        edge_bottom(x, x + w, y, b, d, n),
        edge_right(x + w, y, y + h, r, d, n),
        edge_top(x, x + w, y + h, t, d, n),
        edge_left(x, y, y + h, l, d, n)
    );

module piece_shape(x, y, w, h, b, r, t, l, d) {
    polygon(points = piece_pts(x, y, w, h, b, r, t, l, d));
}

module piece_base(x, y, w, h, b, r, t, l, d, hgt) {
    linear_extrude(height = hgt)
        piece_shape(x, y, w, h, b, r, t, l, d);
}

module qr_2d_sheet() {
    union() {
        for (yy = [0 : len(qr_rows) - 1]) {
            row = qr_rows[len(qr_rows) - 1 - yy];  // flip vertically
            for (xx = [0 : len(row) - 1]) {
                if (row[xx] == 1) {
                    translate([xx * qr_unit_mm, yy * qr_unit_mm])
                        square([qr_unit_mm + 0.01, qr_unit_mm + 0.01], center = false);
                }
            }
        }
    }
}

module qr_on_piece(x, y, w, h, b, r, t, l, d) {
    z_eps_mm = 0.01;
    translate([0, 0, thick_mm - z_eps_mm])
        color(qr_color)
            linear_extrude(height = qr_relief_mm + z_eps_mm)
                intersection() {
                    // Center the QR over the full puzzle footprint.
                    translate([puzzle_w_mm / 2, puzzle_h_mm / 2])
                        scale([puzzle_w_mm / qr_size_mm, puzzle_h_mm / qr_size_mm])
                            translate([-qr_size_mm / 2, -qr_size_mm / 2])
                                qr_2d_sheet();

                    // Clip it to the current piece.
                    piece_shape(x, y, w, h, b, r, t, l, d);
                }
}

union() {
    for (r = [0 : rows - 1]) {
        for (c = [0 : cols - 1]) {
            bottom = (r == 0)        ? 0 : -tab_sign(r - 1, c);
            top    = (r == rows - 1) ? 0 :  tab_sign(r, c);
            left   = (c == 0)        ? 0 : -tab_sign(r, c - 1);
            right  = (c == cols - 1) ? 0 :  tab_sign(r, c);

            px_mm = c * (piece_w_mm + gap_mm);
            py_mm = r * (piece_h_mm + gap_mm);

            color(top_color)
                piece_base(px_mm, py_mm, piece_w_mm, piece_h_mm, bottom, right, top, left, tab_r_mm, thick_mm);

            qr_on_piece(px_mm, py_mm, piece_w_mm, piece_h_mm, bottom, right, top, left, tab_r_mm);
        }
    }
}