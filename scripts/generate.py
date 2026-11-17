#!/usr/bin/env python3
"""Universal CLI for generating pottery stamps with stamp_generator.scad."""

from __future__ import annotations

import argparse
import json
import math
import os
import re
import subprocess
import sys
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_DIR = SCRIPT_DIR.parent
SCAD_FILE = PROJECT_DIR / "stamp_generator.scad"
FONTS_DIR = PROJECT_DIR / "assets" / "fonts"
DEFAULT_TRANSITION_HEIGHT = 5.5
BASE_TOP_SCALE = 0.96


def scad_string(value: str | Path) -> str:
    return json.dumps(str(value), ensure_ascii=False)


def positive_float(value: str) -> float:
    number = float(value)
    if number <= 0:
        raise argparse.ArgumentTypeError("value must be greater than 0")
    return number


def nonnegative_float(value: str) -> float:
    number = float(value)
    if number < 0:
        raise argparse.ArgumentTypeError("value must not be negative")
    return number


def percentage(value: str) -> float:
    number = positive_float(value)
    if number > 5:
        raise argparse.ArgumentTypeError(
            "enter scale as a multiplier, for example 0.75 for 75%"
        )
    return number


def safe_slug(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", value.lower())


def absolute_output(path: Path) -> Path:
    return path if path.is_absolute() else (Path.cwd() / path).resolve()


def download(url: str, destination: Path) -> None:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "pottery-stamps-openscad-generator"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        destination.write_bytes(response.read())


def ensure_google_font(family: str) -> Path:
    family_dir = FONTS_DIR / family
    if any(family_dir.glob("*.ttf")):
        return family_dir

    slug = safe_slug(family)
    if not slug:
        raise RuntimeError("Google Font family name is empty.")

    entries: list[dict] | None = None
    license_group = ""
    for group in ("ofl", "apache", "ufl"):
        api_url = (
            "https://api.github.com/repos/google/fonts/contents/"
            f"{group}/{urllib.parse.quote(slug)}"
        )
        try:
            request = urllib.request.Request(
                api_url,
                headers={"User-Agent": "pottery-stamps-openscad-generator"},
            )
            with urllib.request.urlopen(request, timeout=30) as response:
                entries = json.load(response)
            license_group = group
            break
        except urllib.error.HTTPError as error:
            if error.code != 404:
                raise RuntimeError(
                    f"Google Fonts API returned error {error.code}."
                ) from error

    if entries is None:
        raise RuntimeError(
            f'Font family "{family}" was not found in Google Fonts.'
        )

    font_entries = [
        entry
        for entry in entries
        if entry.get("type") == "file"
        and str(entry.get("name", "")).lower().endswith(".ttf")
        and entry.get("download_url")
    ]
    if not font_entries:
        raise RuntimeError(f'Font family "{family}" contains no TTF files.')

    family_dir.mkdir(parents=True, exist_ok=True)
    for entry in font_entries:
        destination = family_dir / entry["name"]
        print(f"Downloading font {entry['name']}...")
        download(entry["download_url"], destination)

    for entry in entries:
        name = str(entry.get("name", ""))
        if (
            entry.get("type") == "file"
            and name.lower()
            in {"ofl.txt", "license.txt", "apache2.txt", "ufl.txt"}
            and entry.get("download_url")
        ):
            download(entry["download_url"], family_dir / name)

    metadata = {
        "family": family,
        "google_fonts_slug": slug,
        "license_group": license_group,
        "source": f"https://github.com/google/fonts/tree/main/{license_group}/{slug}",
    }
    (family_dir / "font-source.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return family_dir


def svg_aspect_ratio(svg_path: Path) -> float:
    try:
        root = ET.parse(svg_path).getroot()
    except (ET.ParseError, OSError) as error:
        raise RuntimeError(f"Unable to read SVG: {svg_path}") from error

    view_box = root.attrib.get("viewBox")
    if view_box:
        values = [float(value) for value in re.split(r"[,\s]+", view_box.strip())]
        if len(values) == 4 and values[2] > 0 and values[3] > 0:
            return values[2] / values[3]

    def numeric_dimension(name: str) -> float | None:
        raw = root.attrib.get(name)
        if not raw:
            return None
        match = re.match(r"^\s*([0-9]+(?:\.[0-9]+)?)", raw)
        return float(match.group(1)) if match else None

    width = numeric_dimension("width")
    height = numeric_dimension("height")
    if width and height:
        return width / height

    print(
        "Warning: SVG has no usable viewBox; assuming a 1:1 aspect ratio.",
        file=sys.stderr,
    )
    return 1.0


def auto_transition_height(
    motif_width: float,
    motif_height: float,
    base_width: float,
    base_depth: float,
    overhang_angle: float,
) -> float:
    # The rounded triangular body has a minimum centre-to-side distance of
    # roughly one third of its size. Use that conservative value on both axes.
    supported_radius = min(base_width, base_depth) * BASE_TOP_SCALE / 3
    required_expansion = max(
        motif_width / 2 - supported_radius,
        motif_height / 2 - supported_radius,
        0,
    )
    tangent = math.tan(math.radians(overhang_angle))
    required_height = required_expansion / tangent if tangent > 0 else math.inf
    safe_height = max(DEFAULT_TRANSITION_HEIGHT, required_height)
    return math.ceil(safe_height * 2) / 2


def common_definitions(
    args: argparse.Namespace,
    motif_width: float,
    motif_height: float,
) -> dict[str, str | float]:
    transition_height = (
        args.transition_height
        if args.transition_height is not None
        else auto_transition_height(
            motif_width,
            motif_height,
            args.base_width,
            args.base_depth,
            args.overhang_angle,
        )
    )
    return {
        "part": "head",
        "design_height": args.height,
        "design_width": args.width,
        "design_scale": args.scale,
        "relief_mode": "solid",
        "relief_height": args.relief_height,
        "motif_support_height": args.support_height,
        "motif_support_margin": 0,
        "motif_flare_height": args.flare_height,
        "motif_flare_amount": args.flare_amount,
        "relief_top_scale": 1,
        "base_width": args.base_width,
        "base_depth": args.base_depth,
        "transition_height": transition_height,
        "transition_overhang_angle": args.overhang_angle,
    }


def openscad_environment(font_dir: Path | None) -> dict[str, str]:
    environment = os.environ.copy()
    if font_dir is not None:
        existing = environment.get("OPENSCAD_FONT_PATH")
        environment["OPENSCAD_FONT_PATH"] = (
            f"{font_dir}{os.pathsep}{existing}" if existing else str(font_dir)
        )
    return environment


def export_model(
    output: Path,
    definitions: dict[str, str | float],
    font_dir: Path | None,
    openscad_binary: str,
    verbose: bool,
) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    command = [openscad_binary, "--hardwarnings", "-o", str(output)]
    for name, value in definitions.items():
        rendered = (
            scad_string(value)
            if isinstance(value, (str, Path))
            else str(value)
        )
        command.extend(["-D", f"{name}={rendered}"])
    command.append(str(SCAD_FILE))

    if verbose:
        print(" ".join(command))
    subprocess.run(
        command,
        cwd=PROJECT_DIR,
        env=openscad_environment(font_dir),
        check=True,
    )


def resolve_font(args: argparse.Namespace) -> tuple[str, Path | None]:
    if args.google_font:
        font_dir = ensure_google_font(args.google_font)
        family = args.google_font
    else:
        font_dir = None
        family = args.font
    return f"{family}:style={args.font_style}", font_dir


def add_common_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--height", type=positive_float, default=10)
    parser.add_argument(
        "--scale",
        type=percentage,
        default=0.75,
        help="Size multiplier; 0.75 means 75%%.",
    )
    parser.add_argument(
        "--width",
        type=float,
        default=0,
        help="Nominal width; 0 preserves the aspect ratio.",
    )
    parser.add_argument("--relief-height", type=positive_float, default=1.2)
    parser.add_argument("--support-height", type=nonnegative_float, default=0)
    parser.add_argument("--flare-height", type=positive_float, default=2.4)
    parser.add_argument("--flare-amount", type=positive_float, default=1.2)
    parser.add_argument("--base-width", type=positive_float, default=20)
    parser.add_argument("--base-depth", type=positive_float, default=20)
    parser.add_argument(
        "--transition-height",
        type=positive_float,
        help="Calculated automatically when omitted.",
    )
    parser.add_argument(
        "--overhang-angle",
        type=positive_float,
        default=45,
        help="Maximum expansion angle from vertical.",
    )
    parser.add_argument(
        "--openscad",
        default=os.environ.get("OPENSCAD", "openscad"),
    )
    parser.add_argument("--verbose", action="store_true")


def add_font_arguments(parser: argparse.ArgumentParser) -> None:
    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "--google-font",
        help="Google Fonts family; downloaded automatically.",
    )
    group.add_argument(
        "--font",
        default="Cause",
        help="Family name of an installed font.",
    )
    parser.add_argument("--font-style", default="Regular")


def text_command(args: argparse.Namespace) -> None:
    font_spec, font_dir = resolve_font(args)
    effective_height = args.height * args.scale
    effective_width = (
        args.width * args.scale
        if args.width > 0
        else effective_height * max(1, len(args.text) * 0.75)
    )
    definitions = common_definitions(
        args,
        effective_width,
        effective_height,
    )
    definitions.update(
        {
            "source_type": "text",
            "glyph": args.text,
            "font_name": font_spec,
        }
    )
    output = absolute_output(
        args.output or Path("build") / "generated" / "text-stamp.stl"
    )
    export_model(output, definitions, font_dir, args.openscad, args.verbose)
    print(f"Done: {output}")


def svg_command(args: argparse.Namespace) -> None:
    svg_path = args.svg.resolve()
    if not svg_path.is_file():
        raise RuntimeError(f"SVG does not exist: {svg_path}")

    ratio = svg_aspect_ratio(svg_path)
    effective_height = args.height * args.scale
    effective_width = (
        args.width * args.scale
        if args.width > 0
        else effective_height * ratio
    )
    definitions = common_definitions(
        args,
        effective_width,
        effective_height,
    )
    definitions.update(
        {
            "source_type": "svg",
            "svg_file": svg_path,
        }
    )
    output = absolute_output(
        args.output or Path("build") / "generated" / "svg-stamp.stl"
    )
    export_model(output, definitions, None, args.openscad, args.verbose)
    print(
        f"Done: {output} "
        f"(motif {effective_width:.1f} × {effective_height:.1f} mm, "
        f"transition {definitions['transition_height']:.1f} mm)"
    )


def character_filename(character: str) -> str:
    if re.fullmatch(r"[A-Za-z0-9]", character):
        return character
    name = unicodedata.name(character, "").lower().replace(" ", "-")
    return name or f"u{ord(character):04x}"


def alphabet_command(args: argparse.Namespace) -> None:
    font_spec, font_dir = resolve_font(args)
    if args.characters:
        characters = list(args.characters)
    elif args.case == "lowercase":
        characters = list("abcdefghijklmnopqrstuvwxyz")
    elif args.case == "uppercase":
        characters = list("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    else:
        characters = list("0123456789")

    effective_height = args.height * args.scale
    effective_width = (
        args.width * args.scale if args.width > 0 else effective_height
    )
    base_definitions = common_definitions(
        args,
        effective_width,
        effective_height,
    )
    base_definitions.update(
        {
            "source_type": "text",
            "font_name": font_spec,
        }
    )

    args.output_dir = absolute_output(args.output_dir)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for index, character in enumerate(characters, start=1):
        print(f"[{index}/{len(characters)}] {character}")
        definitions = dict(base_definitions)
        definitions["glyph"] = character
        output = args.output_dir / f"{character_filename(character)}.stl"
        export_model(
            output,
            definitions,
            font_dir,
            args.openscad,
            args.verbose,
        )

    manifest = {
        "characters": characters,
        "font": font_spec,
        "height": args.height,
        "scale": args.scale,
        "effective_height": effective_height,
        "parameters": base_definitions,
    }
    (args.output_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Done: {args.output_dir}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate pottery stamps from text, Google Fonts, or SVG.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    text_parser = subparsers.add_parser("text", help="Generate one text stamp.")
    text_parser.add_argument("text")
    text_parser.add_argument("-o", "--output", type=Path)
    add_common_arguments(text_parser)
    add_font_arguments(text_parser)
    text_parser.set_defaults(handler=text_command)

    svg_parser = subparsers.add_parser("svg", help="Generate one SVG stamp.")
    svg_parser.add_argument("svg", type=Path)
    svg_parser.add_argument("-o", "--output", type=Path)
    add_common_arguments(svg_parser)
    svg_parser.set_defaults(handler=svg_command)

    alphabet_parser = subparsers.add_parser(
        "alphabet",
        help="Batch-export a character set.",
    )
    alphabet_parser.add_argument(
        "--case",
        choices=("lowercase", "uppercase", "digits"),
        default="lowercase",
    )
    alphabet_parser.add_argument(
        "--characters",
        help="Custom character string instead of a predefined set.",
    )
    alphabet_parser.add_argument(
        "-o",
        "--output-dir",
        type=Path,
        default=Path("build") / "generated" / "alphabet",
    )
    add_common_arguments(alphabet_parser)
    add_font_arguments(alphabet_parser)
    alphabet_parser.set_defaults(handler=alphabet_command)
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        args.handler(args)
    except (RuntimeError, subprocess.CalledProcessError, OSError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
