#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
output_dir="${1:-${project_dir}/build/alphabet}"
font_path="${project_dir}/assets/fonts/Cause"

if [[ -n "${OPENSCAD_FONT_PATH:-}" ]]; then
    font_path="${font_path}:${OPENSCAD_FONT_PATH}"
fi

if [[ $# -gt 0 ]]; then
    shift
fi

if [[ $# -gt 0 ]]; then
    characters=("$@")
else
    characters=({A..Z})
fi

mkdir -p "${output_dir}"

for character in "${characters[@]}"; do
    if [[ ! "${character}" =~ ^[[:alnum:]]$ ]]; then
        echo "Skipping unsupported filename character: ${character}" >&2
        continue
    fi

    echo "Exporting ${character}.stl"
    OPENSCAD_FONT_PATH="${font_path}" openscad \
        -o "${output_dir}/${character}.stl" \
        -D 'part="head"' \
        -D 'source_type="text"' \
        -D "glyph=\"${character}\"" \
        "${project_dir}/stamp_generator.scad"
done

echo "Done: ${output_dir}"
