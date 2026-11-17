#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
output_dir="${project_dir}/build/cli-smoke-test"

"${script_dir}/generate.py" text a \
    --google-font Cause \
    --height 10 \
    --scale 0.75 \
    -o "${output_dir}/a.stl"

"${script_dir}/generate.py" svg "${project_dir}/examples/flower.svg" \
    --height 28 \
    --scale 1 \
    -o "${output_dir}/flower.stl"

"${script_dir}/generate.py" alphabet \
    --google-font Cause \
    --characters ab \
    --height 10 \
    --scale 0.75 \
    -o "${output_dir}/alphabet"

required_files=(
    "${output_dir}/a.stl"
    "${output_dir}/flower.stl"
    "${output_dir}/alphabet/a.stl"
    "${output_dir}/alphabet/b.stl"
    "${output_dir}/alphabet/manifest.json"
)

for required_file in "${required_files[@]}"; do
    if [[ ! -s "${required_file}" ]]; then
        echo "Missing CLI test output: ${required_file}" >&2
        exit 1
    fi
done

echo "CLI test passed: ${output_dir}"
