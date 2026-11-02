#!/bin/bash
# ==============================================================================
# Script: launch_collate_ooo.sh
# Description: Host-side launcher to collate Out-of-Order (OoO) results via Docker.
# Usage on host (LowPower@D1531):
#   cd ~/Low-Power/gem5
#   ./launch_collate_ooo.sh [output_directory_inside_output]
# Examples:
#   ./launch_collate_ooo.sh /output/ooo/small
#   ./launch_collate_ooo.sh /output/ooo
# ==============================================================================

set -euo pipefail

TARGET_DIR="${1:-/output/ooo/small}"

docker run --rm \
  -v ~/Low-Power/gem5:/gem5 \
  -v ~/Low-Power/outputs/gem5_OIP:/output \
  -w /gem5 \
  -e LANG=C.UTF-8 \
  -e LC_ALL=C.UTF-8 \
  ghcr.io/gem5/ubuntu-22.04_all-dependencies:v23-0 \
  /gem5/collate_ooo_stats.sh "$TARGET_DIR" "${@:2}"
