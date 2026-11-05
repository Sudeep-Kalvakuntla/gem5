#!/bin/bash
# ==============================================================================
# Script: launch_collate_oip_small.sh
# Description: Host-side launcher to collate Small OIP vs Baseline results via Docker.
# Usage on host (LowPower@D1531):
#   cd ~/Low-Power/gem5
#   ./launch_collate_oip_small.sh [before_dir] [after_dir]
# Examples:
#   ./launch_collate_oip_small.sh
#   ./launch_collate_oip_small.sh /output/before_vc6/small /output/oip_vc6/small
# ==============================================================================

set -euo pipefail

BEFORE_ARG="${1:-/output/before_vc6/small}"
AFTER_ARG="${2:-/output/oip_vc6/small}"

docker run --rm \
  -v ~/Low-Power/gem5:/gem5 \
  -v ~/Low-Power/outputs/gem5_OIP:/output \
  -w /gem5 \
  -e LANG=C.UTF-8 \
  -e LC_ALL=C.UTF-8 \
  ghcr.io/gem5/ubuntu-22.04_all-dependencies:v23-0 \
  /gem5/collate_oip_small_stats.sh "$BEFORE_ARG" "$AFTER_ARG" "${@:3}"
