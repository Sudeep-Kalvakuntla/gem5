#!/bin/bash
# ==============================================================================
# Script: run_oip_vc6_medium_study.sh
# Description: Automated end-to-end evaluation comparing Baseline (OIP_Before)
#              against Order-is-Power (OIP) with 6 Virtual Channels (VCs)
#              on PARSEC simmedium workloads.
# Workloads (13 total):
#   blackscholes, bodytrack, canneal, dedup, facesim, ferret, fluidanimate,
#   freqmine, raytrace, streamcluster, swaptions, vips, x264
# ==============================================================================

set -uo pipefail

# Avoid git "dubious ownership" inside Docker containers
git config --global --add safe.directory "*" 2>/dev/null || true

export PYTHONUNBUFFERED=1
STDBUF=""
command -v stdbuf >/dev/null 2>&1 && STDBUF="stdbuf -oL -eL"

ROOT_DIR="/gem5"
[ -d "$ROOT_DIR" ] || ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

find_run_all_medium() {
    if [ -f "${ROOT_DIR}/scripts/parsec/run_all_medium.sh" ]; then
        echo "${ROOT_DIR}/scripts/parsec/run_all_medium.sh"
    elif [ -f "${ROOT_DIR}/run_all_medium.sh" ]; then
        echo "${ROOT_DIR}/run_all_medium.sh"
    elif [ -f "./scripts/parsec/run_all_medium.sh" ]; then
        echo "./scripts/parsec/run_all_medium.sh"
    else
        echo "./run_all_medium.sh"
    fi
}

# Configuration
VCS=6
BUILD_JOBS=2

# Default: All 13 PARSEC medium workloads
DEFAULT_WORKLOADS=(
    "blackscholes"
    "bodytrack"
    "canneal"
    "dedup"
    "facesim"
    "ferret"
    "fluidanimate"
    "freqmine"
    "raytrace"
    "streamcluster"
    "swaptions"
    "vips"
    "x264"
)

# Allow passing custom subset of workloads via CLI: ./run_oip_vc6_medium_study.sh blackscholes canneal
if [ $# -gt 0 ]; then
    WORKLOADS=("$@")
else
    WORKLOADS=("${DEFAULT_WORKLOADS[@]}")
fi

BEFORE_OUT="/output/before_vc6/medium"
AFTER_OUT="/output/oip_vc6/medium"
SUMMARY_FILE="/output/oip_vs_before_vc6_medium_summary.txt"

mkdir -p "$BEFORE_OUT" "$AFTER_OUT"

declare -A BEFORE_PCT
declare -A AFTER_PCT
declare -A BEFORE_DUR
declare -A AFTER_DUR
declare -A REDUCTION_PCT
declare -A BENCH_STATUS

echo "================================================================================"
echo "    Order-is-Power (OIP) vs. Baseline (gem5 Default) -- 6 VCs Medium Study      "
echo "================================================================================"
echo " Total Benchmarks: ${#WORKLOADS[@]}"
echo " Workloads:        ${WORKLOADS[*]}"
echo " Virtual Channels: ${VCS} VCs per virtual network"
echo " Link Width:       64 bits"
echo " Output (Before):  ${BEFORE_OUT}"
echo " Output (After):   ${AFTER_OUT}"
echo " Summary Report:   ${SUMMARY_FILE}"
echo " Started at:       $(date)"
echo "================================================================================"

# Helper function to extract switching percentage
extract_switching() {
    local log="$1"
    local stats="$2"
    local pct=""

    if [ -f "$log" ]; then
        pct=$(grep -oE "Average Link Switching Activity:[[:space:]]*[0-9.]+" "$log" | awk '{print $NF}' | tail -n 1)
    fi
    if [ -z "$pct" ] && [ -f "$stats" ]; then
        local raw=$(grep -E "avg_link_switching_probability" "$stats" | awk '{print $2}' | tail -n 1)
        if [ -n "$raw" ]; then
            pct=$(awk "BEGIN {printf \"%.2f\", $raw * 100.0}")
        fi
    fi
    echo "${pct:-N/A}"
}

# Helper function to extract benchmark duration from log
extract_duration() {
    local log="$1"
    local dur=""
    if [ -f "$log" ]; then
        dur=$(grep -oE "completed in [0-9]+h:[0-9]+m:[0-9]+s" "$log" | awk '{print $NF}' | tail -n 1)
    fi
    echo "${dur:-N/A}"
}

# ------------------------------------------------------------------------------
# PHASE 1: Baseline Default gem5 Arbitration (OIP_Before)
# ------------------------------------------------------------------------------
echo ""
echo "################################################################################"
echo " PHASE 1: Baseline Default gem5 Arbitration (OIP_Before) -- 6 VCs (Medium)"
echo "################################################################################"

echo "[*] Checking out branch: OIP_Before..."
git checkout OIP_Before

echo "[*] Compiling gem5 for Baseline (OIP_Before)..."
scons build/X86_MESI_TWO_LEVEL/gem5.opt --linker=gold -j"${BUILD_JOBS}"

echo "[*] Running Baseline medium workloads: ${WORKLOADS[*]}..."
RUN_ALL_MEDIUM="$(find_run_all_medium)"
OUTPUT_DIR="${BEFORE_OUT}" VCS_PER_VNET="${VCS}" "$RUN_ALL_MEDIUM" "${WORKLOADS[@]}"

# ------------------------------------------------------------------------------
# PHASE 2: Order-is-Power Hamming-Aware Arbitration (Order-is-Power)
# ------------------------------------------------------------------------------
echo ""
echo "################################################################################"
echo " PHASE 2: Order-is-Power Hamming-Aware Arbitration (Order-is-Power) -- 6 VCs (Medium)"
echo "################################################################################"

echo "[*] Checking out branch: Order-is-Power..."
git checkout Order-is-Power

echo "[*] Compiling gem5 for Order-is-Power..."
scons build/X86_MESI_TWO_LEVEL/gem5.opt --linker=gold -j"${BUILD_JOBS}"

echo "[*] Running Order-is-Power medium workloads: ${WORKLOADS[*]}..."
RUN_ALL_MEDIUM="$(find_run_all_medium)"
OUTPUT_DIR="${AFTER_OUT}" VCS_PER_VNET="${VCS}" "$RUN_ALL_MEDIUM" "${WORKLOADS[@]}"

# ------------------------------------------------------------------------------
# PHASE 3: Comparative Analysis & Summary Report
# ------------------------------------------------------------------------------
echo ""
echo "################################################################################"
echo " PHASE 3: Extracting Metrics & Generating Comparative Summary"
echo "################################################################################"

for bench in "${WORKLOADS[@]}"; do
    b_log="${BEFORE_OUT}/simulation-${bench}-med.log"
    b_stats="${BEFORE_OUT}/${bench}_med/stats.txt"
    [ -f "$b_stats" ] || b_stats="${BEFORE_OUT}/stats-${bench}-med.txt"

    a_log="${AFTER_OUT}/simulation-${bench}-med.log"
    a_stats="${AFTER_OUT}/${bench}_med/stats.txt"
    [ -f "$a_stats" ] || a_stats="${AFTER_OUT}/stats-${bench}-med.txt"

    b_val=$(extract_switching "$b_log" "$b_stats")
    a_val=$(extract_switching "$a_log" "$a_stats")
    b_dur=$(extract_duration "$b_log")
    a_dur=$(extract_duration "$a_log")

    BEFORE_PCT["$bench"]="$b_val"
    AFTER_PCT["$bench"]="$a_val"
    BEFORE_DUR["$bench"]="$b_dur"
    AFTER_DUR["$bench"]="$a_dur"

    if [ "$b_val" != "N/A" ] && [ "$a_val" != "N/A" ]; then
        red=$(awk "BEGIN {
            b = $b_val; a = $a_val;
            if (b > 0) printf \"%+.2f%%\", ((b - a) / b) * 100.0;
            else print \"N/A\";
        }")
        REDUCTION_PCT["$bench"]="$red"
        BENCH_STATUS["$bench"]="SUCCESS"
    else
        REDUCTION_PCT["$bench"]="N/A"
        BENCH_STATUS["$bench"]="CHECK LOGS"
    fi
done

# Render and save report
REPORT=$(cat <<EOF
===========================================================================================================================
            Order-is-Power (OIP) vs. Baseline (gem5 Default) -- 6 VCs Medium Evaluation Summary
===========================================================================================================================
 Workloads:          ${WORKLOADS[*]} (PARSEC simmedium)
 Virtual Channels:   ${VCS} VCs per virtual network
 Link Width:         64 bits
 Baseline Outputs:   ${BEFORE_OUT}
 OIP Outputs:        ${AFTER_OUT}
 Completed At:       $(date)
---------------------------------------------------------------------------------------------------------------------------
$(printf "%-16s | %-14s | %-14s | %-18s | %-12s | %-12s | %-12s\n" "Benchmark" "Before (gem5)" "After (OIP)" "Switching Reduction" "Dur (Before)" "Dur (After)" "Status")
$(printf "%-16s-+-%-14s-+-%-14s-+-%-18s-+-%-12s-+-%-12s-+-%-12s\n" "----------------" "--------------" "--------------" "------------------" "------------" "------------" "------------")
$(for bench in "${WORKLOADS[@]}"; do
    b_str="${BEFORE_PCT[$bench]}"
    [ "$b_str" != "N/A" ] && b_str="${b_str}%"
    a_str="${AFTER_PCT[$bench]}"
    [ "$a_str" != "N/A" ] && a_str="${a_str}%"
    printf "%-16s | %-14s | %-14s | %-18s | %-12s | %-12s | %-12s\n" \
        "$bench" \
        "$b_str" \
        "$a_str" \
        "${REDUCTION_PCT[$bench]}" \
        "${BEFORE_DUR[$bench]:-N/A}" \
        "${AFTER_DUR[$bench]:-N/A}" \
        "${BENCH_STATUS[$bench]}"
done)
===========================================================================================================================
 Output Directories on Host (LowPower@D1531):
   - Baseline (Before, 6 VCs): ~/Low-Power/outputs/gem5_OIP/before_vc6/medium/
   - Order-is-Power (After, 6 VCs): ~/Low-Power/outputs/gem5_OIP/oip_vc6/medium/
   - Full Summary Log: ~/Low-Power/outputs/gem5_OIP/oip_vs_before_vc6_medium_summary.txt
===========================================================================================================================
EOF
)

echo "$REPORT" | tee "$SUMMARY_FILE"
echo ""
echo "[+] 6 VCs medium study completed successfully. Summary saved to ${SUMMARY_FILE}"
