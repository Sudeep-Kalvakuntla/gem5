#!/bin/bash
# ==============================================================================
# Script: launch_vc6_study.sh
# Description: Host-side one-click launcher for the 6 VCs OIP study.
# Usage on host (LowPower@D1531):
#   cd ~/Low-Power/gem5
#   ./scripts/studies/launch_vc6_study.sh
# ==============================================================================

set -euo pipefail

echo "================================================================================"
echo " Launching Order-is-Power (OIP) 6 VCs Study"
echo " Workloads: blackscholes, canneal, fluidanimate (simsmall)"
echo " Started:   $(date)"
echo "================================================================================"

docker run --rm \
  --privileged \
  --cap-add=SYS_ADMIN \
  --cap-add=SYS_PTRACE \
  --device=/dev/kvm \
  -e TERM=xterm \
  -e TZ="$(cat /etc/timezone 2>/dev/null || echo UTC)" \
  -v ~/Low-Power/gem5:/gem5 \
  -v ~/Low-Power/parsec:/parsec-benchmark \
  -v ~/Low-Power/outputs/gem5_OIP:/output \
  -v /etc/localtime:/etc/localtime:ro \
  -w /gem5 \
  -e LANG=C.UTF-8 \
  -e LC_ALL=C.UTF-8 \
  -it ghcr.io/gem5/ubuntu-22.04_all-dependencies:v23-0 \
  bash -c 'if [ -f /gem5/scripts/studies/run_oip_vc6_study.sh ]; then exec /gem5/scripts/studies/run_oip_vc6_study.sh "$@"; else exec /gem5/run_oip_vc6_study.sh "$@"; fi' -- "$@"
