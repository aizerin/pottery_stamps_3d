# Parametric Pottery Stamp Generator

A universal OpenSCAD generator for stamps used with ceramic, polymer, and
metal clay. A stamp can be created from text, a Google Font, or any suitable
SVG file. The stamping surface is mirrored automatically so the impression is
readable.

The default design uses a separate printable stamp head with a socket for an
8 mm wooden dowel. It is inspired by interchangeable pottery-stamp systems,
but is not an exact copy of any commercial product.

## Features

- text and individual glyphs rendered with OpenSCAD `text()`;
- automatic Google Fonts download, including the font license;
- arbitrary filled SVG motifs;
- solid or optional outline relief;
- automatic mirroring of the stamping surface;
- a continuous, smoothly flared support from the stamp body to the exact
  contact shape, strengthening small details such as the dot of a lowercase
  `i`;
- no large contact plate: only the motif enters the clay;
- an ergonomic rounded triangular body with a shallow finger waist;
- a socket for a common 8 mm wooden dowel;
- a separately printable handle;
- an impression preview;
- batch export for complete alphabets or custom character sets;
- support-free print orientation and overhang checks.

All dimensions are in millimetres.

## Requirements

- [OpenSCAD](https://openscad.org/) available as `openscad` on `PATH`;
- Python 3.10 or newer for the universal command-line generator;
- internet access only when downloading a Google Font for the first time.

## Quick start

Open the model with the bundled Cause font available to OpenSCAD:

```bash
./scripts/open-in-openscad.sh
```

In OpenSCAD, change `glyph`, dimensions, or relief settings in the
**Customizer**, press **F6**, then choose **File → Export → Export as STL**.

Common command-line targets:

```bash
make head
make handle
make alphabet
make test
```

Generated files are written to `build/`, which is intentionally excluded from
Git because STL exports can be large.

## Ready-to-print example alphabet

The repository includes the approved lowercase Cause alphabet as a compressed
download:

- [Download `cause-lowercase.zip`](examples/generated/cause-lowercase.zip)
  (26 STL files, approximately 33 MB compressed).

The set uses a 10 mm nominal height at 75% scale (7.5 mm effective height),
solid relief, and the continuous 2.4 mm reinforcing flare that reaches the
exact stamping surface. See
[`examples/generated/README.md`](examples/generated/README.md) for the complete
parameter summary and archive checksum.

## Universal command-line generator

`scripts/generate.py` is the recommended interface. It uses the same
parametric OpenSCAD core for text, SVG motifs, and entire alphabets.

Generate one lowercase Cause letter at 75% of its nominal 10 mm height:

```bash
./scripts/generate.py text a \
  --google-font Cause \
  --height 10 \
  --scale 0.75 \
  -o build/generated/a.stl
```

Use another Google Font (downloaded automatically on first use):

```bash
./scripts/generate.py text a \
  --google-font "Roboto Slab" \
  --font-style Regular \
  -o build/generated/roboto-slab-a.stl
```

Generate a stamp from an SVG motif:

```bash
./scripts/generate.py svg examples/flower.svg \
  --height 28 \
  --scale 1 \
  -o build/generated/flower.stl
```

For motifs larger than the body, the script automatically lengthens the
transition so it stays within the configured support-free overhang angle.

Generate the complete lowercase Cause alphabet:

```bash
./scripts/generate.py alphabet \
  --google-font Cause \
  --case lowercase \
  --height 10 \
  --scale 0.75 \
  -o build/generated/cause-lowercase
```

Generate any custom Unicode character set:

```bash
./scripts/generate.py alphabet \
  --google-font Cause \
  --characters 'aábcčdďeéě' \
  -o build/generated/custom-characters
```

Important options:

- `--height 10`: nominal motif height;
- `--scale 0.75`: scale the motif to 75%;
- `--width 20`: optional exact nominal width;
- `--relief-height 1.2`: depth of the resulting impression;
- `--support-height 0`: no thin straight column below the motif;
- `--flare-height 2.4`: height of the continuous reinforcing flare;
- `--flare-amount 1.2`: extra width at the bottom of the flare;
- `--base-width` and `--base-depth`: stamp-body dimensions;
- `--transition-height`: manual body-to-motif transition height;
- `--overhang-angle 45`: support-free overhang limit.

Run `./scripts/generate.py --help` and a subcommand such as
`./scripts/generate.py text --help` for the full CLI reference.

## Direct OpenSCAD export

One letter can also be exported without the Python wrapper:

```bash
OPENSCAD_FONT_PATH="$PWD/assets/fonts/Cause" openscad \
  -o build/B.stl \
  -D 'glyph="B"' \
  -D 'relief_mode="solid"' \
  stamp_generator.scad
```

The legacy batch helper exports A–Z by default:

```bash
./scripts/export-alphabet.sh
```

Or pass an output directory followed by selected characters:

```bash
./scripts/export-alphabet.sh build/lowercase a b c d e
```

## Fonts

Using a font directly is usually simpler than preparing separate SVG files for
an alphabet. The default Cause variable font is bundled in
`assets/fonts/Cause` and used as follows:

```scad
source_type = "text";
glyph = "a";
font_name = "Cause:style=Regular";
design_height = 10;
design_scale = 0.75;
```

The helper scripts set `OPENSCAD_FONT_PATH` automatically. When opening the
SCAD file directly, Cause must be installed on the system; otherwise use
`./scripts/open-in-openscad.sh`. Other local fonts must be installed and
visible under **Help → Font List** in OpenSCAD.

`design_height` controls the actual height of the resulting 2D geometry, not
just the typographic font size. Width is calculated proportionally unless
`design_width` is non-zero. `design_scale` is applied afterwards, so
`10 × 0.75` produces a 7.5 mm-high glyph.

## SVG input

```scad
source_type = "svg";
svg_file = "examples/star.svg";
design_height = 10;
relief_mode = "solid";
```

For reliable results, an SVG should:

- have a correct `viewBox`;
- contain closed, filled paths;
- have text and strokes converted to paths;
- avoid bitmaps, masks, and complex filters;
- keep the motif inside the artboard without large empty margins.

OpenSCAD centres the SVG and resizes it to `design_height`. If a motif looks
unexpectedly small, empty space in its `viewBox` is usually the reason.

## Main OpenSCAD parameters

| Parameter | Default | Meaning |
|---|---:|---|
| `part` | `"head"` | Head, handle, assembly, or impression preview |
| `relief_mode` | `"solid"` | Exact filled silhouette; outline is optional |
| `design_height` | `10` mm | Nominal motif height |
| `design_scale` | `0.75` | Motif size multiplier |
| `relief_height` | `1.2` mm | Impression depth |
| `outline_width` | `0.65` mm | Optional outline thickness |
| `motif_support_height` | `0` mm | No thin straight support below the motif |
| `motif_support_margin` | `0` mm | No secondary enlarged outline |
| `motif_flare_height` | `2.4` mm | Continuous reinforcement height |
| `motif_flare_amount` | `1.2` mm | Reinforcement expansion at its base |
| `motif_flare_steps` | `36` | Approximately 0.1 mm transition layers |
| `transition_height` | `5.5` mm | Body-to-motif transition height |
| `transition_overhang_angle` | `45`° | Maximum support-free expansion angle |
| `base_height` | `16` mm | Length of the finger-grip body |
| `base_width` | `20` mm | Rounded triangular body width |
| `base_depth` | `20` mm | Rounded triangular body depth |
| `base_corner_radius` | `4.2` mm | Body corner radius |
| `base_waist_scale` | `0.88` | Shallow finger-waist scale |
| `base_waist_position` | `0.55` | Vertical waist position |
| `base_top_scale` | `0.96` | Body size at the motif transition |
| `base_profile_steps` | `32` | Smooth body-profile resolution |
| `socket_diameter` | `8.2` mm | Socket for an 8 mm wooden dowel |
| `socket_depth` | `12` mm | Dowel insertion depth |
| `quality` | `72` | Circular surface resolution |

The stamp body is derived from the motif geometry. No rectangular contact
plate dimensions need to be configured.

## Printing recommendations

- Start with a 10 mm nominal glyph. A 4 mm set requires a well-calibrated
  printer, a small nozzle, or resin printing.
- The default `solid` mode preserves the exact filled font shape.
- For FDM, try a 0.12–0.16 mm layer height, three walls, and a slow outer wall.
- The STL is oriented with the connector down and the relief up.
- The 36-layer flare reaches all the way to the contact surface. Fine isolated
  details widen immediately below their exact top outline instead of sitting
  on a fragile vertical filament-width column.
- The rounded triangular body and conical socket roof are designed to print
  without supports at the default settings.
- For a wide SVG, set `design_width` and, when necessary, increase
  `transition_height`. The generator checks the configured overhang limit.
- Print the socket first as a fit test. Typical clearance around an 8 mm dowel
  is 0.15–0.30 mm, depending on the printer.
- Resin generally produces cleaner small text and fine motifs than FDM.
- Clean up strings and rough edges before stamping soft clay.
- Test on scrap clay and avoid pressing the wider body into the surface.

## Testing

```bash
make test
```

The test suite renders representative font, SVG, handle, and batch-export
models and verifies that each expected output exists. OpenSCAD also reports
whether rendered meshes are valid manifold objects.

## License

The original source code, models, SVG examples, and documentation in this
repository are licensed under
[CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).
See [LICENSE.md](LICENSE.md) for the complete repository licensing notice.

The bundled Cause font is third-party software and remains licensed under the
SIL Open Font License 1.1; see `assets/fonts/Cause/OFL.txt`.
