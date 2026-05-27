// Requires qr_data.scad in the same folder.
// qr_data.scad can define either a QR overlay:
//   overlay_mode = "qr";
//   qr_size_mm = ...; or overlay_size_mm = ...;
//   qr_rows = [...];
// or a text overlay:
//   overlay_mode = "text";
//   overlay_text = "...";
//   overlay_text_lines = ["...", "..."];  // optional for multiline text
//   overlay_text_font = "...";              // optional
//   overlay_text_size_mm = ...;              // optional
//   overlay_text_spacing = ...;              // optional
// main.py can generate either form before rendering this file.

include <qr_data.scad>;

// best to keep this a square, we don't account for non-square puzzles in the code below (it will just stretch the QR code).
rows = 3;
cols = 6;

// again, best keeping this a square
piece_w_mm = 30;
piece_h_mm = 30;

// how big the tabs are, in mm. Adjusting this will change the overall size of the puzzle, but not the size of the QR code pattern on top.
tab_r_mm   = 6;
thick_mm   = 4;
gap_mm     = 6;

// How much should the overlay pattern stick out from the surface of the pieces?
// Adjust this to make it more or less visible, 2mm should be more than enough, 1mm should also be fine on any decent printer
qr_relief_mm = 2;

// Colours for display only, makes no difference to the actual output
top_color     = [0.85, 0.85, 0.85];
qr_color      = [0.10, 0.10, 0.10];

arc_n = 28;

// Per-edge tab variation controls. Values are deterministic from each shared edge id,
// so neighboring pieces always get matching but opposite connector shapes.
tab_offset_frac = 0.14;      // max center shift as fraction of edge length
tab_width_min_k = 0.85;      // tab shoulder/head width = tab_r_mm * [min, max]
tab_width_max_k = 1.30;
tab_depth_min_k = 0.76;      // tab depth = tab_r_mm * [min, max]
tab_depth_max_k = 0.98;
tab_curve_min_p = 1.45;      // bigger values make a tighter, rounder crown
tab_curve_max_p = 2.15;
tab_neck_width_k = 0.74;     // neck width as a fraction of the shoulder/head width
tab_neck_min_k = 0.58;       // minimum neck width as a fraction of tab_r_mm
tab_shoulder_depth_k = 0.52; // depth where the tab reaches its locking shoulder
tab_crown_side_k = 0.27;     // roundness of the crown between the shoulders
tab_fit_clearance_mm = 0.25; // baseline clearance for the tab depth/inset fit
tab_width_fit_clearance_mm = tab_fit_clearance_mm; // width clearance before the printable minimum clamp
tab_width_extra_margin_mm = 0.4; // extra side-to-side looseness after clamping; increase if tabs still bind
tab_depth_fit_clearance_mm = tab_fit_clearance_mm; // keep depth/vertical fit unchanged

// Overall footprint of the laid-out puzzle, including the display gaps between pieces.
puzzle_w_mm = cols * piece_w_mm + (cols - 1) * gap_mm;
puzzle_h_mm = rows * piece_h_mm + (rows - 1) * gap_mm;

// Size of one QR module before the full code is scaled to the puzzle footprint.
overlay_mode_value = is_undef(overlay_mode) ? "qr" : overlay_mode;
overlay_size_mm_value = is_undef(overlay_size_mm)
    ? (is_undef(qr_size_mm) ? 100 : qr_size_mm)
    : overlay_size_mm;

overlay_text_value = is_undef(overlay_text) ? "HELLO" : overlay_text;
overlay_text_lines_value = is_undef(overlay_text_lines)
    ? [overlay_text_value]
    : overlay_text_lines;
overlay_text_font_value = is_undef(overlay_text_font)
    ? "Liberation Sans:style=Bold"
    : overlay_text_font;
overlay_text_spacing_value = is_undef(overlay_text_spacing) ? 1.0 : overlay_text_spacing;
overlay_text_line_spacing_value = is_undef(overlay_text_line_spacing) ? 1.15 : overlay_text_line_spacing;
overlay_text_margin_mm_value = is_undef(overlay_text_margin_mm)
    ? min(piece_w_mm, piece_h_mm) * 0.4
    : overlay_text_margin_mm;

qr_unit_mm = overlay_mode_value == "qr" ? overlay_size_mm_value / len(qr_rows) : 0;

// Simple deterministic hash for repeatable per-edge variation.
function hash01(seed, salt = 0) =
    let(v = sin(seed * 12.9898 + salt * 78.233) * 43758.5453)
    v - floor(v);

function clamp(v, lo, hi) = min(max(v, lo), hi);

function edge_width_mm(seed, d) =
    d * (tab_width_min_k + (tab_width_max_k - tab_width_min_k) * hash01(seed, 1));

function edge_depth_mm(seed, d) =
    d * (tab_depth_min_k + (tab_depth_max_k - tab_depth_min_k) * hash01(seed, 2));

function edge_curve_pow(seed) =
    tab_curve_min_p + (tab_curve_max_p - tab_curve_min_p) * hash01(seed, 3);

function tab_center_pos(a0, a1, seed, half_w, d) =
    let(
        edge_len = a1 - a0,
        raw = (a0 + a1) / 2 + edge_len * (hash01(seed, 4) - 0.5) * 2 * tab_offset_frac,
        corner_margin = max(d * 0.7, edge_len * 0.08)
    )
    clamp(raw, a0 + corner_margin + half_w, a1 - corner_margin - half_w);

function cubic_point(p0, p1, p2, p3, t) =
    let(s = 1 - t)
    [
        s * s * s * p0[0] + 3 * s * s * t * p1[0] + 3 * s * t * t * p2[0] + t * t * t * p3[0],
        s * s * s * p0[1] + 3 * s * s * t * p1[1] + 3 * s * t * t * p2[1] + t * t * t * p3[1]
    ];

function tab_curve_mix(p) =
    clamp((p - tab_curve_min_p) / max(0.001, tab_curve_max_p - tab_curve_min_p), 0, 1);

// Rounded neck/shoulder connector. It leaves the edge through a narrow neck,
// flares into a locking shoulder, then rolls over a softer crown.
function lock_tab_local_point(u, head_w, neck_w, amp, p) =
    let(
        m = tab_curve_mix(p),
        neck_half = neck_w / 2,
        head_half = head_w / 2,
        neck_y = amp * (0.18 + 0.03 * m),
        shoulder_y = amp * (tab_shoulder_depth_k + 0.04 * m),
        crown_side = head_w * (tab_crown_side_k + 0.03 * m),
        crown_y = amp * (0.83 - 0.03 * m)
    )
    u < 0.25
        ? cubic_point(
            [-neck_half, 0],
            [-neck_half, neck_y],
            [-head_half, neck_y],
            [-head_half, shoulder_y],
            u / 0.25
          )
    : u < 0.5
        ? cubic_point(
            [-head_half, shoulder_y],
            [-head_half, crown_y],
            [-crown_side, amp],
            [0, amp],
            (u - 0.25) / 0.25
          )
    : u < 0.75
        ? cubic_point(
            [0, amp],
            [crown_side, amp],
            [head_half, crown_y],
            [head_half, shoulder_y],
            (u - 0.5) / 0.25
          )
        : cubic_point(
            [head_half, shoulder_y],
            [head_half, neck_y],
            [neck_half, neck_y],
            [neck_half, 0],
            (u - 0.75) / 0.25
          );

function signed_tab_width(tab_w, sign) =
    max(tab_r_mm * 1.35, tab_w + (sign > 0 ? -2 * tab_width_fit_clearance_mm : 2 * tab_width_fit_clearance_mm))
        + (sign > 0 ? -tab_width_extra_margin_mm : tab_width_extra_margin_mm);

function tab_neck_width(head_w) =
    max(tab_r_mm * tab_neck_min_k, head_w * tab_neck_width_k);

function signed_tab_amp(tab_amp, sign) =
    max(tab_r_mm * 0.35, tab_amp + (sign > 0 ? -tab_depth_fit_clearance_mm : tab_depth_fit_clearance_mm));

function tab_mid_bottom(cx, neck_w, head_w, y, sign, amp, p, n=arc_n) =
    [for (i = [1 : n - 1])
        let(
            u = i / n,
            pt = lock_tab_local_point(u, head_w, neck_w, amp, p),
            xx = cx + pt[0],
            yy = y - sign * pt[1]
        )
        [xx, yy]
    ];

function tab_mid_top(cx, neck_w, head_w, y, sign, amp, p, n=arc_n) =
    [for (i = [1 : n - 1])
        let(
            u = 1 - i / n,
            pt = lock_tab_local_point(u, head_w, neck_w, amp, p),
            xx = cx + pt[0],
            yy = y + sign * pt[1]
        )
        [xx, yy]
    ];

function tab_mid_right(x, cy, neck_w, head_w, sign, amp, p, n=arc_n) =
    [for (i = [1 : n - 1])
        let(
            u = i / n,
            pt = lock_tab_local_point(u, head_w, neck_w, amp, p),
            yy = cy + pt[0],
            xx = x + sign * pt[1]
        )
        [xx, yy]
    ];

function tab_mid_left(x, cy, neck_w, head_w, sign, amp, p, n=arc_n) =
    [for (i = [1 : n - 1])
        let(
            u = 1 - i / n,
            pt = lock_tab_local_point(u, head_w, neck_w, amp, p),
            yy = cy + pt[0],
            xx = x - sign * pt[1]
        )
        [xx, yy]
    ];

function h_edge_seed(hr, hc) = hr * cols + hc + 1;
function v_edge_seed(vr, vc) = 10000 + vr * (cols - 1) + vc + 1;

// Each edge helper returns a point list for one side of a piece.
// sign = 0 gives a flat border edge, positive/negative values produce opposite tab directions.
function edge_bottom(x0, x1, y, sign, d, seed, n=arc_n) =
    let(
        tab_w = signed_tab_width(edge_width_mm(seed, d), sign),
        neck_w = tab_neck_width(tab_w),
        tab_amp = signed_tab_amp(edge_depth_mm(seed, d), sign),
        tab_p = edge_curve_pow(seed),
        cx = tab_center_pos(x0, x1, seed, tab_w / 2, d),
        x_start = cx - neck_w / 2,
        x_end = cx + neck_w / 2
    )
    sign == 0
        ? [[x1, y]]
        : concat(
            [[x_start, y]],
            tab_mid_bottom(cx, neck_w, tab_w, y, sign, tab_amp, tab_p, n),
            [[x_end, y], [x1, y]]
          );

function edge_right(x, y0, y1, sign, d, seed, n=arc_n) =
    let(
        tab_w = signed_tab_width(edge_width_mm(seed, d), sign),
        neck_w = tab_neck_width(tab_w),
        tab_amp = signed_tab_amp(edge_depth_mm(seed, d), sign),
        tab_p = edge_curve_pow(seed),
        cy = tab_center_pos(y0, y1, seed, tab_w / 2, d),
        y_start = cy - neck_w / 2,
        y_end = cy + neck_w / 2
    )
    sign == 0
        ? [[x, y1]]
        : concat(
            [[x, y_start]],
            tab_mid_right(x, cy, neck_w, tab_w, sign, tab_amp, tab_p, n),
            [[x, y_end], [x, y1]]
          );

function edge_top(x0, x1, y, sign, d, seed, n=arc_n) =
    let(
        tab_w = signed_tab_width(edge_width_mm(seed, d), sign),
        neck_w = tab_neck_width(tab_w),
        tab_amp = signed_tab_amp(edge_depth_mm(seed, d), sign),
        tab_p = edge_curve_pow(seed),
        cx = tab_center_pos(x0, x1, seed, tab_w / 2, d),
        x_start = cx - neck_w / 2,
        x_end = cx + neck_w / 2
    )
    sign == 0
        ? [[x0, y]]
        : concat(
            [[x_end, y]],
            tab_mid_top(cx, neck_w, tab_w, y, sign, tab_amp, tab_p, n),
            [[x_start, y], [x0, y]]
          );

function edge_left(x, y0, y1, sign, d, seed, n=arc_n) =
    let(
        tab_w = signed_tab_width(edge_width_mm(seed, d), sign),
        neck_w = tab_neck_width(tab_w),
        tab_amp = signed_tab_amp(edge_depth_mm(seed, d), sign),
        tab_p = edge_curve_pow(seed),
        cy = tab_center_pos(y0, y1, seed, tab_w / 2, d),
        y_start = cy - neck_w / 2,
        y_end = cy + neck_w / 2
    )
    sign == 0
        ? [[x, y0]]
        : concat(
            [[x, y_end]],
            tab_mid_left(x, cy, neck_w, tab_w, sign, tab_amp, tab_p, n),
            [[x, y_start], [x, y0]]
          );

// Alternate tab direction like a checkerboard so neighboring pieces always match.
function tab_sign(r, c) = ((r + c) % 2 == 0) ? 1 : -1;

// Build a closed 2D outline by walking around the piece clockwise.
function piece_pts(x, y, w, h, b, r, t, l, d, b_seed, r_seed, t_seed, l_seed, n=arc_n) =
    concat(
        [[x, y]],
        edge_bottom(x, x + w, y, b, d, b_seed, n),
        edge_right(x + w, y, y + h, r, d, r_seed, n),
        edge_top(x, x + w, y + h, t, d, t_seed, n),
        edge_left(x, y, y + h, l, d, l_seed, n)
    );

module piece_shape(x, y, w, h, b, r, t, l, d, b_seed, r_seed, t_seed, l_seed) {
    polygon(points = piece_pts(x, y, w, h, b, r, t, l, d, b_seed, r_seed, t_seed, l_seed));
}

module piece_base(x, y, w, h, b, r, t, l, d, b_seed, r_seed, t_seed, l_seed, hgt) {
    linear_extrude(height = hgt)
        piece_shape(x, y, w, h, b, r, t, l, d, b_seed, r_seed, t_seed, l_seed);
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

module text_2d_sheet(sheet_w_mm, sheet_h_mm) {
    text_box_w_mm = max(1, sheet_w_mm - 2 * overlay_text_margin_mm_value);
    text_box_h_mm = max(1, sheet_h_mm - 2 * overlay_text_margin_mm_value);
    line_count = max(1, len(overlay_text_lines_value));
    base_text_size_mm = 10;
    line_pitch_mm = base_text_size_mm * overlay_text_line_spacing_value;

    translate([sheet_w_mm / 2, sheet_h_mm / 2])
        if (is_undef(overlay_text_size_mm)) {
            resize([text_box_w_mm, text_box_h_mm])
                union() {
                    for (line_idx = [0 : line_count - 1]) {
                        translate([0, ((line_count - 1) / 2 - line_idx) * line_pitch_mm])
                            text(
                                overlay_text_lines_value[line_idx],
                                size = base_text_size_mm,
                                font = overlay_text_font_value,
                                halign = "center",
                                valign = "center",
                                spacing = overlay_text_spacing_value
                            );
                    }
                }
        } else {
            union() {
                for (line_idx = [0 : line_count - 1]) {
                    translate([0, ((line_count - 1) / 2 - line_idx) * overlay_text_size_mm * overlay_text_line_spacing_value])
                        text(
                            overlay_text_lines_value[line_idx],
                            size = overlay_text_size_mm,
                            font = overlay_text_font_value,
                            halign = "center",
                            valign = "center",
                            spacing = overlay_text_spacing_value
                        );
                }
            }
        }
}

module overlay_2d_sheet(sheet_w_mm, sheet_h_mm) {
    if (overlay_mode_value == "qr") {
        qr_2d_sheet();
    } else if (overlay_mode_value == "text") {
        text_2d_sheet(sheet_w_mm, sheet_h_mm);
    } else {
        echo(str("Unsupported overlay_mode: ", overlay_mode_value));
    }
}

module overlay_on_piece(x, y, w, h, b, r_tab, t, l, d, b_seed, r_seed, t_seed, l_seed, grid_r, grid_c) {
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
                    // Center the overlay over the contiguous puzzle footprint (without gaps).
                    // Apply the full overlay on the logical grid, then translate by display offset.
                    translate([x - logical_x_mm, y - logical_y_mm, 0])
                        if (overlay_mode_value == "qr") {
                            translate([contiguous_w_mm / 2, contiguous_h_mm / 2])
                                scale([contiguous_w_mm / overlay_size_mm_value, contiguous_h_mm / overlay_size_mm_value])
                                    translate([-overlay_size_mm_value / 2, -overlay_size_mm_value / 2])
                                        overlay_2d_sheet(contiguous_w_mm, contiguous_h_mm);
                        } else {
                            overlay_2d_sheet(contiguous_w_mm, contiguous_h_mm);
                        }

                    // Clip it to the current piece.
                    piece_shape(x, y, w, h, b, r_tab, t, l, d, b_seed, r_seed, t_seed, l_seed);
                }
}

// Build every piece in place, then add only the part of the overlay that lands on that outline.
union() {
    for (r = [0 : rows - 1]) {
        for (c = [0 : cols - 1]) {
            // Border pieces get flat outer edges; interior edges alternate tab direction.
            bottom = (r == 0)        ? 0 : -tab_sign(r - 1, c);
            top    = (r == rows - 1) ? 0 :  tab_sign(r, c);
            left   = (c == 0)        ? 0 : -tab_sign(r, c - 1);
            right  = (c == cols - 1) ? 0 :  tab_sign(r, c);

            // Shared edge ids keep tab geometry identical on both touching pieces.
            bottom_seed = (r == 0) ? 0 : h_edge_seed(r - 1, c);
            top_seed    = (r == rows - 1) ? 0 : h_edge_seed(r, c);
            left_seed   = (c == 0) ? 0 : v_edge_seed(r, c - 1);
            right_seed  = (c == cols - 1) ? 0 : v_edge_seed(r, c);

            // Pieces are spaced apart by gap_mm for previewing and exporting.
            px_mm = c * (piece_w_mm + gap_mm);
            py_mm = r * (piece_h_mm + gap_mm);

            color(top_color)
                piece_base(px_mm, py_mm, piece_w_mm, piece_h_mm, bottom, right, top, left, tab_r_mm, bottom_seed, right_seed, top_seed, left_seed, thick_mm);

            overlay_on_piece(px_mm, py_mm, piece_w_mm, piece_h_mm, bottom, right, top, left, tab_r_mm, bottom_seed, right_seed, top_seed, left_seed, r, c);
        }
    }
}
