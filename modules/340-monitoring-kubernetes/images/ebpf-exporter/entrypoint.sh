#!/bin/bash

set -euo pipefail

version_constraint_prefix="#kernel-version-constraint "
actual_config_path="/tmp/actual-config.yaml"

correct_kernel_version_code="0"
wrong_kernel_version_code="13"

echo "programs:" > "$actual_config_path"

for program_path in /config/*.yaml; do
    program_body="$(cat "$program_path")"

    raw_constraints="$(grep "$version_constraint_prefix" <<<"$program_body")"
    constraints="$(sed "s/$version_constraint_prefix//g" <<<"$raw_constraints")"

    ret="$(kernel-version-parser "$constraints"; echo $?)"

    if [[ "$ret" == "$correct_kernel_version_code" ]]; then
        echo "$program_body" >> "$actual_config_path"
    elif [[ "$ret" != "$wrong_kernel_version_code" ]]; then
        exit 1
    fi
done

/usr/local/bin/ebpf_exporter "$@"
