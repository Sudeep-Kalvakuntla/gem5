#!/bin/bash
# ==============================================================================
# Script: run_oip_vc6_study.sh
# Description: Automated end-to-end evaluation comparing Baseline (OIP_Before)
#              against Order-is-Power (OIP) with 6 Virtual Channels (VCs).
#              Workloads: blackscholes, canneal, fluidanimate (simsmall).
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

find_run_all_small() {
    if [ -f "${ROOT_DIR}/scripts/parsec/run_all_small.sh" ]; then
        echo "${ROOT_DIR}/scripts/parsec/run_all_small.sh"
    elif [ -f "${ROOT_DIR}/run_all_small.sh" ]; then
        echo "${ROOT_DIR}/run_all_small.sh"
    elif [ -f "./scripts/parsec/run_all_small.sh" ]; then
        echo "./scripts/parsec/run_all_small.sh"
    else
        echo "./run_all_small.sh"
    fi
}

# Configuration
VCS=6
BUILD_JOBS=2
WORKLOADS=("blackscholes" "canneal" "fluidanimate")

BEFORE_OUT="/output/before_vc6/small"
AFTER_OUT="/output/oip_vc6/small"
SUMMARY_FILE="/output/oip_vs_before_vc6_summary.txt"

mkdir -p "$BEFORE_OUT" "$AFTER_OUT"

declare -A BEFORE_PCT
declare -A AFTER_PCT
declare -A BEFORE_DUR
declare -A AFTER_DUR
declare -A REDUCTION_PCT
declare -A BENCH_STATUS

echo "================================================================================"
echo "    Order-is-Power (OIP) vs. Baseline (gem5 Default) -- 6 VCs Study Runner     "
echo "================================================================================"
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

# ------------------------------------------------------------------------------
# PHASE 1: Baseline Default gem5 Arbitration (OIP_Before)
# ------------------------------------------------------------------------------
echo ""
echo "################################################################################"
echo " PHASE 1: Baseline Default gem5 Arbitration (OIP_Before) -- 6 VCs"
echo "################################################################################"

echo "[*] Checking out branch: OIP_Before..."
git checkout OIP_Before

echo "[*] Compiling gem5 for Baseline (OIP_Before)..."
scons build/X86_MESI_TWO_LEVEL/gem5.opt --linker=gold -j"${BUILD_JOBS}"

echo "[*] Running Baseline workloads: ${WORKLOADS[*]}..."
RUN_ALL_SMALL="$(find_run_all_small)"
OUTPUT_DIR="${BEFORE_OUT}" VCS_PER_VNET="${VCS}" "$RUN_ALL_SMALL" "${WORKLOADS[@]}"

# ------------------------------------------------------------------------------
# PHASE 2: Order-is-Power Hamming-Aware Arbitration (Order-is-Power)
# ------------------------------------------------------------------------------
echo ""
echo "################################################################################"
echo " PHASE 2: Order-is-Power Hamming-Aware Arbitration (Order-is-Power) -- 6 VCs"
echo "################################################################################"

echo "[*] Checking out branch: Order-is-Power..."
git checkout Order-is-Power

echo "[*] Compiling gem5 for Order-is-Power..."
scons build/X86_MESI_TWO_LEVEL/gem5.opt --linker=gold -j"${BUILD_JOBS}"

echo "[*] Running Order-is-Power workloads: ${WORKLOADS[*]}..."
RUN_ALL_SMALL="$(find_run_all_small)"
OUTPUT_DIR="${AFTER_OUT}" VCS_PER_VNET="${VCS}" "$RUN_ALL_SMALL" "${WORKLOADS[@]}"

# ------------------------------------------------------------------------------
# PHASE 3: Comparative Analysis & Summary Report
# ------------------------------------------------------------------------------
echo ""
echo "################################################################################"
echo " PHASE 3: Extracting Metrics & Generating Comparative Summary"
echo "################################################################################"

for bench in "${WORKLOADS[@]}"; do
    b_log="${BEFORE_OUT}/simulation-${bench}-small.log"
    b_stats="${BEFORE_OUT}/${bench}_small/stats.txt"
    [ -f "$b_stats" ] || b_stats="${BEFORE_OUT}/stats-${bench}-small.txt"

    a_log="${AFTER_OUT}/simulation-${bench}-small.log"
    a_stats="${AFTER_OUT}/${bench}_small/stats.txt"
    [ -f "$a_stats" ] || a_stats="${AFTER_OUT}/stats-${bench}-small.txt"

    b_val=$(extract_switching "$b_log" "$b_stats")
    a_val=$(extract_switching "$a_log" "$a_stats")

    BEFORE_PCT["$bench"]="$b_val"
    AFTER_PCT["$bench"]="$a_val"

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
========================================================================================================
            Order-is-Power (OIP) vs. Baseline (gem5 Default) -- 6 VCs Evaluation Summary
========================================================================================================
 Workloads:          ${WORKLOADS[*]} (PARSEC simsmall)
 Virtual Channels:   ${VCS} VCs per virtual network
 Link Width:         64 bits
 Baseline Outputs:   ${BEFORE_OUT}
 OIP Outputs:        ${AFTER_OUT}
 Completed At:       $(date)
--------------------------------------------------------------------------------------------------------
$(printf "%-18s | %-16s | %-16s | %-18s | %-12s\n" "Benchmark" "Before (gem5)" "After (OIP)" "Switching Reduction" "Status")
$(printf "%-18s-+-%-16s-+-%-16s-+-%-18s-+-%-12s\n" "------------------" "----------------" "----------------" "------------------" "------------")
$(for bench in "${WORKLOADS[@]}"; do
    b_str="${BEFORE_PCT[$bench]}"
    [ "$b_str" != "N/A" ] && b_str="${b_str}%"
    a_str="${AFTER_PCT[$bench]}"
    [ "$a_str" != "N/A" ] && a_str="${a_str}%"
    printf "%-18s | %-16s | %-16s | %-18s | %-12s\n" \
        "$bench" \
        "$b_str" \
        "$a_str" \
        "${REDUCTION_PCT[$bench]}" \
        "${BENCH_STATUS[$bench]}"
done)
========================================================================================================
 Output Directories on Host (LowPower@D1531):
   - Baseline (Before, 6 VCs): ~/Low-Power/outputs/gem5_OIP/before_vc6/small/
   - Order-is-Power (After, 6 VCs): ~/Low-Power/outputs/gem5_OIP/oip_vc6/small/
   - Full Summary Log: ~/Low-Power/outputs/gem5_OIP/oip_vs_before_vc6_summary.txt
========================================================================================================
EOF
)

echo "$REPORT" | tee "$SUMMARY_FILE"
echo ""
echo "[+] 6 VCs study completed successfully. Summary saved to ${SUMMARY_FILE}"
