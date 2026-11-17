#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
font_path="${project_dir}/assets/fonts/Cause"

if [[ -n "${OPENSCAD_FONT_PATH:-}" ]]; then
    font_path="${font_path}:${OPENSCAD_FONT_PATH}"
fi

OPENSCAD_FONT_PATH="${font_path}" openscad "${project_dir}/stamp_generator.scad"
