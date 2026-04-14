// Requires qr_data.scad in the same folder.
// qr_data.scad must define:
//   qr_size_mm = ...;
//   qr_rows = [...];
// that is all handled by main.py, so you can just run that to generate qr_data.scad before rendering this file.

include <qr_data.scad>;

// best to keep this a square, we don't account for non-square puzzles in the code below (it will just stretch the QR code).
rows = 8;
cols = 8;

// again, best keeping this a square
piece_w_mm = 15;
piece_h_mm = 15;

// how big the tabs are, in mm. Adjusting this will change the overall size of the puzzle, but not the size of the QR code pattern on top.
tab_r_mm   = 3;
thick_mm   = 4;
gap_mm     = 5;

// How much should the QR code pattern stick out from the surface of the pieces? 
// Adjust this to make it more or less visible, 2mm should be more than enough, 1mm should also be find on any decent printer
qr_relief_mm = 2;

// Colours for display only, makes no difference to the actual output
top_color     = [0.85, 0.85, 0.85];
qr_color      = [0.10, 0.10, 0.10];

arc_n = 16;

// Overall footprint of the laid-out puzzle, including the display gaps between pieces.
puzzle_w_mm = cols * piece_w_mm + (cols - 1) * gap_mm;
puzzle_h_mm = rows * piece_h_mm + (rows - 1) * gap_mm;

// Size of one QR module before the full code is scaled to the puzzle footprint.
qr_unit_mm = qr_size_mm / len(qr_rows);

// Return intermediate points along an arc so each tab edge can be approximated as a polygon.
function arc_mid(cx, cy, r, a1, a2, n=arc_n) =
    [for (i = [1 : n - 1])
        [cx + r * cos(a1 + (a2 - a1) * i / n),
         cy + r * sin(a1 + (a2 - a1) * i / n)]
    ];

// Each edge helper returns a point list for one side of a piece.
// sign = 0 gives a flat border edge, positive/negative values produce opposite tab directions.
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

// Alternate tab direction like a checkerboard so neighboring pieces always match.
function tab_sign(r, c) = ((r + c) % 2 == 0) ? 1 : -1;

// Build a closed 2D outline by walking around the piece clockwise.
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

// Convert the QR matrix into a sheet of tiny squares that can later be clipped per piece.
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

module qr_on_piece(x, y, w, h, b, r_tab, t, l, d, grid_r, grid_c) {
    // Sink the QR layer by a tiny epsilon so it cleanly touches the base without z-fighting.
    z_eps_mm = 0.01;
    
    // Calculate the logical grid position of this piece (without gaps).
    logical_x_mm = grid_c * piece_w_mm;
    logical_y_mm = grid_r * piece_h_mm;
    
    // Calculate the contiguous footprint (without gaps) for proper QR alignment across pieces.
    contiguous_w_mm = cols * piece_w_mm;
    contiguous_h_mm = rows * piece_h_mm;
    
    translate([0, 0, thick_mm - z_eps_mm])
        color(qr_color)
            linear_extrude(height = qr_relief_mm + z_eps_mm)
                intersection() {
                    // Center the QR over the contiguous puzzle footprint (without gaps).
                    // Apply QR code centered on the full grid, then translate by display offset.
                    translate([x - logical_x_mm, y - logical_y_mm, 0])
                        translate([contiguous_w_mm / 2, contiguous_h_mm / 2])
                            scale([contiguous_w_mm / qr_size_mm, contiguous_h_mm / qr_size_mm])
                                translate([-qr_size_mm / 2, -qr_size_mm / 2])
                                    qr_2d_sheet();

                    // Clip it to the current piece.
                    piece_shape(x, y, w, h, b, r_tab, t, l, d);
                }
}

// Build every piece in place, then add only the part of the QR that lands on that outline.
union() {
    for (r = [0 : rows - 1]) {
        for (c = [0 : cols - 1]) {
            // Border pieces get flat outer edges; interior edges alternate tab direction.
            bottom = (r == 0)        ? 0 : -tab_sign(r - 1, c);
            top    = (r == rows - 1) ? 0 :  tab_sign(r, c);
            left   = (c == 0)        ? 0 : -tab_sign(r, c - 1);
            right  = (c == cols - 1) ? 0 :  tab_sign(r, c);

            // Pieces are spaced apart by gap_mm for previewing and exporting.
            px_mm = c * (piece_w_mm + gap_mm);
            py_mm = r * (piece_h_mm + gap_mm);

            color(top_color)
                piece_base(px_mm, py_mm, piece_w_mm, piece_h_mm, bottom, right, top, left, tab_r_mm, thick_mm);

            qr_on_piece(px_mm, py_mm, piece_w_mm, piece_h_mm, bottom, right, top, left, tab_r_mm, r, c);
        }
    }
}