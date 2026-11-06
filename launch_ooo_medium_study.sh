#!/bin/bash
# ==============================================================================
# Script: launch_ooo_medium_study.sh
# Description: Host-side one-click launcher for Out-of-Order (OoO) medium workloads.
# Usage on host (LowPower@D1531):
#   cd ~/Low-Power/gem5
#   ./launch_ooo_medium_study.sh [workloads...]
# Examples:
#   ./launch_ooo_medium_study.sh                      # runs all 13 medium workloads
#   ./launch_ooo_medium_study.sh blackscholes canneal # runs specific workloads
# ==============================================================================

set -euo pipefail

echo "================================================================================"
echo " Launching Out-of-Order (Body Flit Reordering) PARSEC Medium Batch Execution"
echo " Started: $(date)"
echo " Output:  ~/Low-Power/outputs/gem5_OIP/ooo/medium"
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
  bash -c 'git config --global --add safe.directory /gem5 && git checkout OoO-23.0.0.1 && scons build/X86_MESI_TWO_LEVEL/gem5.opt --linker=gold -j2 && OUTPUT_DIR=/output/ooo/medium ./run_all_medium.sh "$@"' -- "$@"
