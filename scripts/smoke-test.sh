#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
output_dir="${project_dir}/build/smoke-test"
font_path="${project_dir}/assets/fonts/Cause"

if [[ -n "${OPENSCAD_FONT_PATH:-}" ]]; then
    font_path="${font_path}:${OPENSCAD_FONT_PATH}"
fi

mkdir -p "${output_dir}"

OPENSCAD_FONT_PATH="${font_path}" openscad \
    -o "${output_dir}/letter-a.stl" \
    -D 'part="head"' \
    -D 'glyph="A"' \
    "${project_dir}/stamp_generator.scad"

OPENSCAD_FONT_PATH="${font_path}" openscad \
    -o "${output_dir}/star.stl" \
    -D 'part="head"' \
    -D 'source_type="svg"' \
    -D 'svg_file="examples/star.svg"' \
    -D 'relief_mode="solid"' \
    "${project_dir}/stamp_generator.scad"

OPENSCAD_FONT_PATH="${font_path}" openscad \
    -o "${output_dir}/handle.stl" \
    -D 'part="handle"' \
    "${project_dir}/stamp_generator.scad"

for model in "${output_dir}"/*.stl; do
    if [[ ! -s "${model}" ]]; then
        echo "Empty export: ${model}" >&2
        exit 1
    fi
done

echo "Smoke test passed: ${output_dir}"
