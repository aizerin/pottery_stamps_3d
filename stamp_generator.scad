/*
 * Parametric pottery stamp generator
 *
 * Units: millimetres
 * Z axis: the head is exported in print orientation, with the connector
 *         at the bottom and mirrored relief at the top.
 */

/* [Output] */
part = "head"; // [head:Stamp head,handle:Handle,assembly:Assembly,impression:Impression preview]

/* [Motif] */
source_type = "text"; // [text:Text or glyph,svg:SVG file]
glyph = "a";
font_name = "Cause:style=Regular";
svg_file = "examples/star.svg";
design_height = 10;
design_width = 0; // 0 = preserve the height-based aspect ratio
design_scale = 0.75; // 1 = 100 %, 0.75 = 75 %
mirror_design = true;
relief_mode = "solid"; // [solid:Exact filled silhouette,outline:Optional outline]
outline_width = 0.65;

/* [Relief] */
relief_height = 1.2;
relief_top_scale = 1.0;

/* [Head without a contact plate] */
motif_support_height = 0;
motif_support_margin = 0;
motif_flare_height = 2.4;
motif_flare_amount = 1.2;
motif_flare_steps = 36;
transition_height = 5.5;
transition_overhang_angle = 45;

/* [Rounded triangular grip body] */
base_height = 16;
base_width = 20;
base_depth = 20;
base_corner_radius = 4.2;
base_waist_scale = 0.88;
base_waist_position = 0.55;
base_top_scale = 0.96;
base_profile_steps = 32;

/* [Handle socket] */
socket_diameter = 8.2;
socket_depth = 12;
socket_lead_in = 0.45;
socket_roof_height = 4.2;

/* [Printable handle] */
handle_style = "ergonomic"; // [ergonomic:Ergonomic,dowel:Simple dowel]
handle_length = 82;
handle_diameter = 17;
handle_peg_diameter = 7.9;
handle_peg_length = 11.5;

/* [Impression preview] */
clay_width = 38;
clay_depth = 32;
clay_thickness = 3;
impression_depth = 1.0;

/* [Quality] */
quality = 72;
$fn = quality;
epsilon = 0.02;
effective_design_height = design_height * design_scale;
effective_design_width = design_width > 0 ? design_width * design_scale : 0;
motif_total_height =
    motif_flare_height + motif_support_height + relief_height;


module raw_motif_2d() {
    assert(design_scale > 0, "design_scale must be greater than 0.");

    if (source_type == "text") {
        assert(len(glyph) > 0, "glyph must not be empty.");

        if (design_width > 0)
            resize([effective_design_width, effective_design_height])
                text(
                    glyph,
                    size = design_height,
                    font = font_name,
                    halign = "center",
                    valign = "center",
                    spacing = 1
                );
        else
            resize([0, effective_design_height], auto = true)
                text(
                    glyph,
                    size = design_height,
                    font = font_name,
                    halign = "center",
                    valign = "center",
                    spacing = 1
                );
    } else if (source_type == "svg") {
        assert(len(svg_file) > 0, "Set svg_file when source_type=\"svg\".");

        if (design_width > 0)
            resize([effective_design_width, effective_design_height])
                import(file = svg_file, center = true, dpi = 96);
        else
            resize([0, effective_design_height], auto = true)
                import(file = svg_file, center = true, dpi = 96);
    } else {
        assert(false, str("Unknown source_type: ", source_type));
    }
}


module styled_motif_2d() {
    if (relief_mode == "solid") {
        raw_motif_2d();
    } else if (relief_mode == "outline") {
        assert(outline_width > 0, "outline_width must be greater than 0.");

        difference() {
            offset(delta = outline_width / 2)
                raw_motif_2d();
            offset(delta = -outline_width / 2)
                raw_motif_2d();
        }
    } else {
        assert(false, str("Unknown relief_mode: ", relief_mode));
    }
}


module prepared_motif_2d(mirrored = mirror_design) {
    if (mirrored)
        mirror([1, 0, 0])
            styled_motif_2d();
    else
        styled_motif_2d();
}


module prepared_raw_motif_2d(mirrored = mirror_design) {
    if (mirrored)
        mirror([1, 0, 0])
            raw_motif_2d();
    else
        raw_motif_2d();
}


module motif_3d(mirrored = mirror_design, height = relief_height) {
    assert(height > 0, "Relief height must be greater than 0.");
    assert(relief_top_scale > 0 && relief_top_scale <= 1,
        "relief_top_scale must be in the interval (0, 1].");

    linear_extrude(height = height, scale = relief_top_scale)
        prepared_motif_2d(mirrored);
}


module motif_support_2d() {
    offset(delta = motif_support_margin)
        prepared_raw_motif_2d();
}


module motif_flare_2d(amount = motif_flare_amount) {
    offset(delta = amount)
        prepared_motif_2d();
}


module motif_flare_support() {
    layer_height = motif_total_height / motif_flare_steps;

    /*
     * Each successive layer is slightly narrower. Smoothstep creates a
     * continuous flare and preserves separate motif parts, such as an i dot.
     */
    for (step = [0 : motif_flare_steps - 1]) {
        progress = step / motif_flare_steps;
        amount = motif_flare_amount * (1 - smoothstep(progress));

        translate([0, 0, step * layer_height])
            linear_extrude(height = layer_height + epsilon)
                motif_flare_2d(amount);
    }
}


module rounded_rectangle_2d(size = [10, 10], radius = 2) {
    assert(size.x > 2 * radius && size.y > 2 * radius,
        "Corner radius is too large for the body dimensions.");

    offset(r = radius)
        square([size.x - 2 * radius, size.y - 2 * radius], center = true);
}


module rounded_triangle_2d(size = [18, 18], radius = 2) {
    assert(
        size.x > 4 * radius && size.y > 4 * radius,
        "Corner radius is too large for the triangular body dimensions."
    );

    // The triangle centroid, handle socket, and motif all share the origin.
    offset(r = radius)
        offset(delta = -radius)
            polygon([
                [-size.x / 2, -size.y / 3],
                [ size.x / 2, -size.y / 3],
                [0, 2 * size.y / 3]
            ]);
}


module base_slice(z, size, radius) {
    translate([0, 0, z])
        linear_extrude(height = epsilon)
            rounded_triangle_2d(size, radius);
}


function smoothstep(value) =
    value * value * (3 - 2 * value);


function mix(from, to, amount) =
    from + (to - from) * amount;


function base_scale_at(position) =
    position <= base_waist_position
        ? mix(
            1,
            base_waist_scale,
            smoothstep(position / base_waist_position)
        )
        : mix(
            base_waist_scale,
            base_top_scale,
            smoothstep(
                (position - base_waist_position)
                    / (1 - base_waist_position)
            )
        );


module stamp_base() {
    /*
     * Several short lofts create a continuous finger waist without a kink.
     * Smoothstep has zero slope at the beginning, waist, and end.
     */
    for (step = [0 : base_profile_steps - 1]) {
        start = step / base_profile_steps;
        end = (step + 1) / base_profile_steps;
        start_scale = base_scale_at(start);
        end_scale = base_scale_at(end);

        hull() {
            base_slice(
                base_height * start,
                [base_width, base_depth] * start_scale,
                base_corner_radius * start_scale
            );
            base_slice(
                base_height * end - epsilon,
                [base_width, base_depth] * end_scale,
                base_corner_radius * end_scale
            );
        }
    }
}


module transition_body() {
    top_size = [base_width, base_depth] * base_top_scale;
    top_radius = base_corner_radius * base_top_scale;

    hull() {
        base_slice(
            base_height - epsilon,
            top_size,
            top_radius
        );

        translate([0, 0, base_height + transition_height - epsilon])
            linear_extrude(height = epsilon)
                hull()
                    motif_flare_2d();
    }
}


module head_shell() {
    union() {
        stamp_base();
        transition_body();

        translate([0, 0, base_height + transition_height - epsilon])
            motif_flare_support();
    }
}


module handle_socket() {
    union() {
        translate([0, 0, -epsilon])
            cylinder(h = socket_depth + epsilon, d = socket_diameter);

        // The conical roof closes the socket at a support-free print angle.
        translate([0, 0, socket_depth - epsilon])
            cylinder(
                h = socket_roof_height + epsilon,
                d1 = socket_diameter,
                d2 = 0
            );

        translate([0, 0, -epsilon])
            cylinder(
                h = socket_lead_in + epsilon,
                d1 = socket_diameter + 2 * socket_lead_in,
                d2 = socket_diameter
            );
    }
}


module stamp_head() {
    assert(motif_support_height >= 0,
        "motif_support_height must not be negative.");
    assert(motif_flare_height > 0 && motif_flare_amount >= 0,
        "Flare parameters must not be negative.");
    assert(motif_flare_steps >= 4,
        "Use at least 4 steps for a smooth flare.");
    assert(
        relief_mode != "outline" || motif_support_margin >= outline_width / 2,
        "Motif support must cover the outer outline overhang.");
    assert(base_width > socket_diameter + 4 && base_depth > socket_diameter + 4,
        "Leave at least 2 mm of material around the handle socket.");
    assert(base_waist_scale >= 0.75 && base_waist_scale < base_top_scale,
        "base_waist_scale must be below base_top_scale and at least 0.75.");
    assert(base_waist_position > 0.3 && base_waist_position < 0.75,
        "base_waist_position must be in the interval (0.3, 0.75).");
    assert(base_profile_steps >= 6,
        "Use at least 6 steps for a smooth body profile.");
    assert(base_top_scale > 0.75 && base_top_scale <= 1,
        "base_top_scale must be in the interval (0.75, 1].");
    assert(socket_roof_height >= socket_diameter / 2,
        "For support-free printing, socket_roof_height must be at least half the socket diameter.");
    assert(socket_depth + socket_roof_height <= base_height + transition_height,
        "socket_depth must be below the total stamp-head body height.");
    assert(
        effective_design_height + 2 * motif_flare_amount
            <= base_depth * base_top_scale
                + 2 * transition_height * tan(transition_overhang_angle),
        "Motif is too tall for the overhang limit; increase transition_height."
    );
    assert(
        effective_design_width <= 0
            || effective_design_width + 2 * motif_flare_amount
                <= base_width * base_top_scale
                    + 2 * transition_height * tan(transition_overhang_angle),
        "Motif is too wide for the overhang limit; increase transition_height."
    );

    difference() {
        head_shell();
        handle_socket();
    }
}


module ergonomic_grip() {
    hull() {
        cylinder(h = 2, d = handle_diameter * 0.72);

        translate([0, 0, handle_length * 0.20])
            cylinder(h = 2, d = handle_diameter);
    }

    hull() {
        translate([0, 0, handle_length * 0.20])
            cylinder(h = 2, d = handle_diameter);

        translate([0, 0, handle_length - 2])
            cylinder(h = 2, d = handle_diameter * 0.72);
    }
}


module printed_handle() {
    assert(handle_peg_diameter < socket_diameter,
        "Handle peg must be smaller than the stamp-head socket.");

    union() {
        cylinder(h = handle_peg_length + epsilon, d = handle_peg_diameter);

        translate([0, 0, handle_peg_length])
            if (handle_style == "dowel")
                cylinder(h = handle_length, d = socket_diameter - 0.2);
            else if (handle_style == "ergonomic")
                ergonomic_grip();
            else
                assert(false, str("Unknown handle_style: ", handle_style));
    }
}


module assembled_stamp() {
    stamp_head();

    // The handle is inserted into the socket and points away from the relief.
    translate([0, 0, handle_peg_length])
        rotate([180, 0, 0])
            printed_handle();
}


module clay_impression() {
    difference() {
        translate([-clay_width / 2, -clay_depth / 2, -clay_thickness])
            cube([clay_width, clay_depth, clay_thickness]);

        // After physically flipping the head, the impression is readable.
        translate([0, 0, -impression_depth])
            linear_extrude(height = impression_depth + epsilon)
                prepared_motif_2d(false);
    }
}


if (part == "head")
    stamp_head();
else if (part == "handle")
    printed_handle();
else if (part == "assembly")
    assembled_stamp();
else if (part == "impression")
    clay_impression();
else
    assert(false, str("Unknown part: ", part));
