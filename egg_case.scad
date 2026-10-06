// =====================================================================
//  EGG CASE  for  APPLE WATCH SERIES 7  (41 mm / 45 mm)
// ---------------------------------------------------------------------
//  A smooth, palm-sized egg that turns the watch (band removed) into a
//  handheld. Two printed parts clip together around the watch:
//
//    shell : domed front with a soft-edged screen window and retaining
//            lip, a thumb rest, a cove for the Digital Crown and side
//            button, and a speaker port.
//    back  : flat-bottomed back with 4 snap clips, 4 spring pads that hold
//            the watch rattle-free, and a hole for the magnetic charger.
//
//  Coordinates: Z = 0 is the back (table) face, +Z points out of the
//  screen. Origin is the centre of the egg outline.
//
//  Built for OpenSCAD 2021.01+ (renders in seconds with the Manifold
//  backend in recent builds: Preferences > Advanced > Backend).
// =====================================================================

/* [Output] */
// Which part to generate
part = "assembly"; // [shell, back, fit_test, assembly, exploded, section, watch, clash]
// Apple Watch Series 7 case size
watch_size = 45; // [41:41 mm, 45:45 mm]

/* [Fit tuning] */
// Gap between the watch sides and the pocket wall (per side)
side_clearance = 0.30; // [0.10:0.05:0.60]
// Raise (+) the spring pads if the watch rattles; lower (-) if the back is hard to close
pad_offset = 0.0; // [-1.0:0.1:1.0]
// How far each snap bead overlaps its groove (bigger = tighter clip)
snap_interference = 0.25; // [0.10:0.05:0.45]

/* [Features] */
// Shallow sculpted dimple below the screen
thumb_rest = true;
// Sound tunnel to the watch speaker (left side)
speaker_port = true;
// Hole in the back for the magnetic charging puck
charger_hole = true;

/* [Shape (sizes are for the 45 mm version; 41 mm scales down)] */
// Overall egg width
egg_width = 66.0;   // [60:0.5:80]
// Overall egg height
egg_height = 78.0;  // [70:0.5:100]
// Egg-ness: >0 makes the bottom fuller than the top
egg_taper = 0.12;   // [0:0.01:0.25]
// Screen centre above the egg centre
screen_offset = 5.5; // [0:0.5:15]
// Thickness of the back part (thicker = fuller, heavier back)
back_thickness = 3.0; // [3:0.5:6]
// Rounding radius of the back edge
back_round = 4.0;   // [2:0.5:10]
// Front dome: how far in from the edge the curve reaches
front_round_w = 7.0; // [4:0.5:16]
// Front dome: height of the curve
front_round_h = 6.5; // [3:0.5:10]
// Front face height above the watch glass
bezel_height = 2.5; // [2:0.1:4]
// Round-over radius where the face meets the screen window
window_edge_r = 1.2; // [0:0.1:3]
// Thumb rest: footprint diameter
thumb_size = 20.0;  // [12:0.5:30]
// Thumb rest: depth at the centre
thumb_depth = 1.0;  // [0.3:0.1:2.5]
// Thumb rest: shift up (+) / down (-) from midway between screen and egg bottom
thumb_shift = 0.0;  // [-8:0.5:8]

/* [Hidden] */
$fn = 96;
eps = 0.01;
big = 200;

// ---------------------------------------------------------------------
//  Watch reference dimensions (Apple Watch Series 7, aluminium)
// ---------------------------------------------------------------------
S   = watch_size == 41 ? 0.92 : 1.0;   // shape scale relative to 45 mm
W   = watch_size == 41 ? 35.0 : 38.0;  // case width  (X)
H   = watch_size == 41 ? 41.0 : 45.0;  // case height (Y)
// plan-view corner radius. Deliberately a little under the real value:
// a pocket corner that is too sharp leaves a hidden gap, one that is too
// round would bind.
WR  = watch_size == 41 ? 7.8 : 8.5;
GLASS_EDGE_R = 3.0;                    // rounding of the front crystal edge
WATCH_BODY = 9.7;                      // aluminium back plane -> crystal top

// Digital Crown + side button (right-hand side), relative to the watch
CROWN_Y  = 7.0 * S;
BUTTON_Y = -6.5 * S;

// ---------------------------------------------------------------------
//  Egg body
// ---------------------------------------------------------------------
EA = egg_width/2 * S;   // half-width parameter
EB = egg_height/2 * S;  // half-height
EK = egg_taper;
YW = screen_offset * S; // watch centre

// Z stack (everything hangs off the back thickness)
ZS   = back_thickness;  // seam between back (below) and shell (above)
ZCB  = ZS - 0.8;        // floor of the watch recess in the back
ZG   = ZS + 10.0;       // nominal top of the watch crystal
T    = ZG + bezel_height; // front face height
RB   = back_round;
AF   = front_round_w;
BF   = front_round_h;
ZF   = T - BF;

// Retaining lip: the watch's rounded crystal edge seats on a 45 deg chamfer
C     = side_clearance;
ZCH0  = ZG - 2*GLASS_EDGE_R + sqrt(2)*(GLASS_EDGE_R + C) - C; // chamfer start
LIPC  = 1.6;            // chamfer runs in to this inset from the watch outline
LIP   = 2.2;            // window edge inset from the watch outline
ZLU   = ZCH0 + C + LIPC; // underside of the lip

// ---------------------------------------------------------------------
//  2D helpers
// ---------------------------------------------------------------------
module rrect(w, h, r) {
    rr = min(r, w/2 - eps, h/2 - eps);
    offset(r = rr) square([w - 2*rr, h - 2*rr], center = true);
}
// watch outline grown by o (negative = inset)
module wrr(o) translate([0, YW]) rrect(W + 2*o, H + 2*o, max(WR + o, 0.5));

function egg_pt(t) = [EA*cos(t)*(1 - EK*sin(t)), EB*sin(t)];
function egg_dt(t) = [EA*(-sin(t)*(1 - EK*sin(t)) - EK*cos(t)*cos(t)), EB*cos(t)];
function egg_pts(n = 240) = [for (i = [0:n-1]) egg_pt(360*i/n)];
module egg2d(inset = 0) offset(delta = -inset) polygon(egg_pts());

module slab(z) translate([0, 0, z]) linear_extrude(eps) children();

// Local frame on the egg outline at parameter t:
//   x = along the edge, y = outward normal, z = z
module at_egg(t) {
    p = egg_pt(t);
    d = egg_dt(t);
    u = d / norm(d);
    n = [u[1], -u[0]];
    multmatrix([[u[0], n[0], 0, p[0]],
                [u[1], n[1], 0, p[1]],
                [0, 0, 1, 0],
                [0, 0, 0, 1]]) children();
}
// extrude a 2D profile drawn in (y, z) along local x from x0 to x1
module along_x(x0, x1)
    multmatrix([[0, 0, 1, 0], [1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 0, 1]])
        translate([0, 0, x0]) linear_extrude(x1 - x0) children();

// ---------------------------------------------------------------------
//  Outer body: hull of inset egg slices
// ---------------------------------------------------------------------
// inset of the back edge at height z (45 deg chamfer where the arc would
// overhang the bed by more than 45 deg)
function back_inset(z) =
    z >= RB ? 0 :
    z <= RB*(1 - 1/sqrt(2)) ? RB*(1 - 1/sqrt(2)) + (RB*(1 - 1/sqrt(2)) - z) :
    RB - sqrt(RB*RB - (RB - z)*(RB - z));
// height of the front surface at a given inset from the outline
function front_z(i) = i >= AF ? T : ZF + BF*sqrt(1 - (1 - i/AF)*(1 - i/AF));

// [z, inset] pairs, back to front
function body_profile() = concat(
    [[0, back_inset(0)]],
    [for (a = [45:-5:0]) [RB - RB*sin(a), RB - RB*cos(a)]],
    [for (a = [0:5:90])  [ZF + BF*sin(a), AF*(1 - cos(a))]]
);
module body() hull() for (p = body_profile()) slab(p[0]) egg2d(p[1]);

// ---------------------------------------------------------------------
//  Watch pocket (air), from z0 up through the front face
// ---------------------------------------------------------------------
WIN_R = min(window_edge_r, T - ZLU - 0.4);
module pocket(z0) {
    translate([0, 0, z0]) linear_extrude(ZCH0 - z0 + eps) wrr(C);
    hull() { slab(ZCH0) wrr(C); slab(ZLU) wrr(-LIPC); }
    // vertical window wall, then a round-over into the face
    translate([0, 0, ZLU - eps]) linear_extrude(T - WIN_R - ZLU + 2*eps) wrr(-LIP);
    if (WIN_R > 0) for (i = [0:7]) hull() for (a = [i*90/8, (i + 1)*90/8])
        slab(T - WIN_R + WIN_R*sin(a)) wrr(-LIP + WIN_R*(1 - cos(a)));
    translate([0, 0, T - eps]) linear_extrude(5) wrr(-LIP + WIN_R);
}

// ---------------------------------------------------------------------
//  Thumb rest: a shallow spherical dimple below the screen
// ---------------------------------------------------------------------
THUMB_Y  = ((YW - H/2) + (-EB)) / 2 + thumb_shift*S;
THUMB_R  = (pow(thumb_size*S/2, 2) + thumb_depth*thumb_depth) / (2*thumb_depth);
module thumb_dimple()
    translate([0, THUMB_Y, front_z(THUMB_Y + EB) + THUMB_R - thumb_depth]) sphere(THUMB_R, $fn = 192);

// ---------------------------------------------------------------------
//  Cove for the Digital Crown and side button (right side).
//  Two "teardrop" spheres (ceiling capped at a 50 deg overhang so it
//  prints without supports), centred low so the cove opens towards the
//  back-right and the front face keeps its egg outline.
// ---------------------------------------------------------------------
CROWN_Z    = ZG - WATCH_BODY + 3.6;  // nominal crown axis height
COVE_R     = 11.0;
COVE_ZC    = ZS;
COVE_SY    = 0.7;             // squash along Y -> shorter mouth
COVE_REACH = W/2 + 1.5;       // crown sticks ~1.5 mm out into the cove
COVE_X     = COVE_REACH + sqrt(COVE_R*COVE_R - (CROWN_Z - COVE_ZC)*(CROWN_Z - COVE_ZC));
module teardrop_ball(r, a = 50) hull() {
    sphere(r, $fn = 96);
    translate([0, 0, r/sin(a)]) sphere(0.05, $fn = 8);
}
module cove_balls() hull() for (y = [YW + BUTTON_Y, YW + CROWN_Y])
    translate([COVE_X, y, COVE_ZC]) scale([1, COVE_SY, 1]) teardrop_ball(COVE_R);
module cove() {
    intersection() {
        cove_balls();
        translate([-big/2, -big/2, ZS - 1]) cube(big);
    }
    crown_passage(ZS - 1);
}
// Straight-sided passage (open to the back) so the crown and button can
// drop in with the watch. Its outline is the cove's own outline at the
// passage roof, swept inwards, so nothing is left hanging over the cove.
module cove_footprint() projection(cut = true) translate([0, 0, -ZCH0 - 0.3]) cove_balls();
module crown_passage(z0) translate([0, 0, z0]) linear_extrude(ZCH0 - z0) {
    hull() { cove_footprint(); translate([-8, 0]) cove_footprint(); }
    translate([W/2 + C - 0.5, YW + BUTTON_Y - 7*S]) square([2.5, (CROWN_Y - BUTTON_Y) + 11.6*S]);
}
// relief in the back under the crown and button
module crown_relief() translate([W/2 + C - 0.5, YW + BUTTON_Y - 7*S, ZCB])
    cube([4.5, (CROWN_Y - BUTTON_Y) + 11.6*S, ZS]);

// ---------------------------------------------------------------------
//  Speaker port (left side)
// ---------------------------------------------------------------------
module speaker() {
    hull() for (dy = [-6.5*S, 6.5*S])
        translate([-W/2 + 1, YW + dy, CROWN_Z - 0.3]) rotate([0, -90, 0]) cylinder(r = 2.3, h = 40, $fn = 32);
}

// ---------------------------------------------------------------------
//  Snap fingers (on the back) and their slots (in the shell)
// ---------------------------------------------------------------------
FINGER_T  = [62, 118, 238, 302]; // positions around the egg (deg)
FT    = 1.2;    // finger thickness
FW    = 10.0;   // finger width
FL    = 8.0;    // finger height above the seam
FIO   = max(2.8, back_inset(ZS) + 2.0); // outer face inset from the egg outline
FCLR  = 0.15;   // running clearance
FFLEX = 0.7;    // room behind the finger to flex into
FBP   = snap_interference + FCLR; // bead protrusion
FZ0   = ZS + 6.2; // bottom of the bead

module bead_2d(grow = 0) offset(delta = grow) polygon([
    [-FIO - 0.2, FZ0 - 0.2],
    [-FIO, FZ0],
    [-FIO + FBP, FZ0 + FBP],
    [-FIO + FBP, FZ0 + FBP + 0.3],
    [-FIO, FZ0 + FBP + 0.3 + 1.73*FBP],
    [-FIO - 0.2, FZ0 + FBP + 0.3 + 1.73*FBP + 0.2]]);

module finger_2d() {
    polygon([[-FIO - FT, ZS - 0.6], [-FIO, ZS - 0.6], [-FIO, ZS + FL - 0.4],
             [-FIO - 0.4, ZS + FL], [-FIO - FT, ZS + FL]]);
    bead_2d();
}
module fingers() for (t = FINGER_T) at_egg(t) along_x(-FW/2, FW/2) finger_2d();

module finger_slots() for (t = FINGER_T) at_egg(t) {
    along_x(-FW/2 - 0.3, FW/2 + 0.3) {
        translate([-FIO - FT - FFLEX, ZS - 1]) square([FT + FFLEX + FCLR, FL + 1.4]);
        bead_2d(FCLR);
    }
}

// ---------------------------------------------------------------------
//  Spring pads (on the back): bridge-beams with a pad in the middle that
//  press the watch's aluminium back corners. Each flexes ~1.4 mm.
// ---------------------------------------------------------------------
BL   = 26.0 * S;  // free span
BW   = 2.2;       // beam width
BT   = 0.8;       // beam thickness
BGAP = 0.8;       // slot gap either side of the beam
BZ1  = ZCB;       // beam top
BZ0  = BZ1 - BT;  // beam bottom (room underneath = flex range)
PAD_TOP = ZS + 1.05 + pad_offset;
PAD_XY = [for (sx = [-1, 1]) for (sy = [-1, 1]) [sx*(W/2 - 6.25), sy*(H/2 - 6.25)]];

module at_pad(p) translate([p[0], YW + p[1], 0]) rotate(atan2(p[1], p[0]) + 90) children();
module spring_slots(h = ZS + 2) for (p = PAD_XY) at_pad(p)
    translate([-BL/2, -BW/2 - BGAP, -1]) cube([BL, BW + 2*BGAP, h + 1]);
// slots open upwards only under the watch; elsewhere a thin skin bridges
// over them so they don't show in the crown cove
module spring_slot_cut() {
    intersection() { spring_slots(); translate([0, 0, -2]) linear_extrude(ZS + 4) wrr(C); }
    spring_slots(BZ1 + 0.4);
}
module springs() for (p = PAD_XY) at_pad(p) {
    translate([-BL/2 - 1, -BW/2, BZ0]) cube([BL + 2, BW, BT]);
    hull() {
        translate([-2.0, -BW/2, BZ1 - eps]) cube([4.0, BW, eps]);
        translate([-0.9, -BW/2 + 0.35, PAD_TOP - 0.4]) cube([1.8, BW - 0.7, 0.4]);
    }
}

// ---------------------------------------------------------------------
//  Parts
// ---------------------------------------------------------------------
module shell() {
    difference() {
        intersection() { body(); translate([-big/2, -big/2, ZS]) cube(big); }
        pocket(ZS - 1);
        cove();
        if (speaker_port) speaker();
        if (thumb_rest) thumb_dimple();
        finger_slots();
    }
}

CHG_D = watch_size == 41 ? 29.0 : 30.0;   // Apple puck is ~27.5 mm
module back() {
    difference() {
        union() {
            difference() {
                intersection() { body(); translate([-big/2, -big/2, -1]) cube([big, big, ZS + 1]); }
                // recess for the watch back
                translate([0, 0, ZCB]) linear_extrude(ZS) wrr(C);
                spring_slot_cut();
                if (charger_hole) translate([0, YW, -1]) {
                    cylinder(d = CHG_D, h = ZS + 2);
                    cylinder(d1 = CHG_D + 3.6, d2 = CHG_D, h = 1.8);   // 0.8 mm x 45 deg lead-in
                }
            }
            springs();
            fingers();
        }
        difference() { crown_relief(); spring_slots(); }
        // pry slot at the bottom seam (use a coin / fingernail)
        translate([-6*S, -EB - 2, ZS - 1.0]) cube([12*S, 6 + back_inset(ZS - 1), 2]);
    }
}

module fit_test() {
    intersection() {
        shell();
        difference() {
            translate([0, 0, ZS - 1]) linear_extrude(T + 5) wrr(C + 3.2);
            translate([0, 0, ZS - 2]) linear_extrude(T + 8) wrr(C - 4);
        }
    }
}

// ---------------------------------------------------------------------
//  Approximate watch (for previews and clearance checks only)
// ---------------------------------------------------------------------
ZAB = ZG - WATCH_BODY;   // nominal aluminium back plane
module watch_face() {     // simple analogue face at 10:09 (preview only)
    translate([0, YW, ZG + 0.02]) {
        color("#d8d8d8") linear_extrude(0.05) for (a = [0:30:330])
            rotate(a) translate([0, 13*S]) square([a % 90 == 0 ? 1.2 : 0.7, a % 90 == 0 ? 3.2 : 2.0], center = true);
        color("#f4f4f4") linear_extrude(0.06) {
            rotate(-(10 + 9/60)*30) translate([-0.6, 0]) square([1.2, 9*S]);   // hour hand
            rotate(-9*6) translate([-0.45, 0]) square([0.9, 13*S]);             // minute hand
        }
        color("#ff8a3d") linear_extrude(0.07) { rotate(-32*6) translate([-0.25, -2]) square([0.5, 15*S]); circle(1.1); }
    }
}
module watch() {
    color("#1c1c1e") {
        hull() {
            slab(ZAB) wrr(-2.5);
            translate([0, 0, ZAB + 2.5]) linear_extrude(ZG - GLASS_EDGE_R - ZAB - 2.5) wrr(0);
            for (a = [0:15:90]) slab(ZG - GLASS_EDGE_R + GLASS_EDGE_R*sin(a)) wrr(-GLASS_EDGE_R*(1 - cos(a)));
        }
        translate([0, YW, ZAB]) scale([1, 1, 1.0/15]) sphere(r = 15);              // sensor dome
    }
    color("#3a3a3c") {
        translate([W/2 - 0.5, YW + CROWN_Y, CROWN_Z]) rotate([0, 90, 0]) cylinder(d = 7, h = 3.5); // crown
        hull() for (dy = [-5, 5]) translate([W/2 - 0.5, YW + BUTTON_Y + dy*S, CROWN_Z])
            rotate([0, 90, 0]) cylinder(d = 2.4, h = 1.3, $fn = 24);                // side button
    }
    watch_face();
}

// preview colours
SHELL_COL = "#ece7dd";   // warm off-white
BACK_COL  = "#5b6168";   // graphite

// ---------------------------------------------------------------------
if (part == "shell")         color(SHELL_COL) translate([0, 0, -ZS]) shell();   // printed back-face down
else if (part == "back")     color(BACK_COL) back();                            // printed outer face down
else if (part == "fit_test") color(SHELL_COL) translate([0, 0, -ZS]) fit_test();
else if (part == "watch")    watch();
else if (part == "info")     // key numbers for tools/check.py
    echo(str("INFO {\"ZS\":", ZS, ",\"ZLU\":", ZLU, ",\"T\":", T, ",\"ZG\":", ZG, ",\"EA\":", EA, ",\"EB\":", EB,
             ",\"EK\":", EK, ",\"YW\":", YW, ",\"W\":", W, ",\"H\":", H, ",\"WR\":", WR, ",\"LIP\":", LIP,
             ",\"S\":", S, ",\"CROWN_Y\":", CROWN_Y, ",\"THUMB_Y\":", THUMB_Y, "}"));
else if (part == "section")  intersection() {
    union() { color(SHELL_COL) shell(); color(BACK_COL) back(); watch(); }
    translate([-big/2, YW + CROWN_Y, -big/2]) cube(big);
}
else if (part == "clash") {   // debug: should only show the spring pads touching the watch
    intersection() { shell(); watch(); }
    intersection() { back(); watch(); }
    intersection() { shell(); back(); }
}
else if (part == "exploded") {
    color(SHELL_COL) translate([0, 0, 30]) shell();
    translate([0, 0, 15]) watch();
    color(BACK_COL) back();
}
else {
    color(SHELL_COL) shell();
    color(BACK_COL) back();
    watch();
}
