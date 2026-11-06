#!/bin/bash
# ==============================================================================
# Script: collate_ooo_medium_stats.sh
# Description: Collates and summarizes simulation statistics for Out-of-Order
#              (Body Flit Reordering) NoC runs on PARSEC medium workloads.
# Usage:
#   ./collate_ooo_medium_stats.sh [log_directory] [workloads...]
# Examples:
#   ./collate_ooo_medium_stats.sh
#   ./collate_ooo_medium_stats.sh /output/ooo/medium
#   ./collate_ooo_medium_stats.sh ~/Low-Power/outputs/gem5_OIP/ooo/medium
# ==============================================================================

set -uo pipefail

TARGET_DIR="${1:-}"

# Auto-detect target directory if not provided
if [ -z "$TARGET_DIR" ]; then
    if [ -n "${OUTPUT_DIR:-}" ] && [ -d "$OUTPUT_DIR" ]; then
        TARGET_DIR="$OUTPUT_DIR"
    fi
fi

if [ -z "$TARGET_DIR" ]; then
    CANDIDATES=(
        "/output/ooo/medium"
        "${HOME}/Low-Power/outputs/gem5_OIP/ooo/medium"
        "/output/ooo"
        "${HOME}/Low-Power/outputs/gem5_OIP/ooo"
        "./outputs/gem5_OIP/ooo/medium"
        "./outputs/gem5_OIP/ooo"
        "./output/ooo/medium"
        "./output/ooo"
        "."
    )
    for c in "${CANDIDATES[@]}"; do
        if [ -d "$c" ] && (compgen -G "$c/simulation-*-med.log" >/dev/null || compgen -G "$c/stats-*-med.txt" >/dev/null || compgen -G "$c/*_med" >/dev/null); then
            TARGET_DIR="$c"
            break
        fi
    done
fi

if [ -z "$TARGET_DIR" ] || [ ! -d "$TARGET_DIR" ]; then
    if [ -d "/output/ooo/medium" ]; then
        TARGET_DIR="/output/ooo/medium"
    elif [ -d "${HOME}/Low-Power/outputs/gem5_OIP/ooo/medium" ]; then
        TARGET_DIR="${HOME}/Low-Power/outputs/gem5_OIP/ooo/medium"
    elif [ -d "/output/ooo" ]; then
        TARGET_DIR="/output/ooo"
    elif [ -d "${HOME}/Low-Power/outputs/gem5_OIP/ooo" ]; then
        TARGET_DIR="${HOME}/Low-Power/outputs/gem5_OIP/ooo"
    else
        TARGET_DIR="."
    fi
fi

# Expand tilde if passed literally
TARGET_DIR="${TARGET_DIR/#\~/$HOME}"

# Parse custom workloads if passed as 2nd+ arguments
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

if [ $# -gt 1 ]; then
    shift
    WORKLOADS=("$@")
else
    WORKLOADS=("${DEFAULT_WORKLOADS[@]}")
fi

declare -A BEFORE_PCT
declare -A AFTER_PCT
declare -A REDUCTION_PCT
declare -A DURATION
declare -A PACKETS
declare -A BENCH_STATUS

TOTAL_REDUCTION=0
SUCCESS_COUNT=0

# Helper function to find log file for a benchmark
find_log() {
    local b="$1"
    for cand in \
        "${TARGET_DIR}/simulation-${b}-med.log" \
        "${TARGET_DIR}/${b}_med/system.pc.com_1.device" \
        "${TARGET_DIR}/simulation-${b}.log" \
        "${TARGET_DIR}/${b}/system.pc.com_1.device" \
        "${TARGET_DIR}/${b}.log"
    do
        if [ -f "$cand" ]; then
            echo "$cand"
            return
        fi
    done
    echo ""
}

# Helper function to find stats file for a benchmark
find_stats() {
    local b="$1"
    for cand in \
        "${TARGET_DIR}/stats-${b}-med.txt" \
        "${TARGET_DIR}/${b}_med/stats.txt" \
        "${TARGET_DIR}/stats-${b}.txt" \
        "${TARGET_DIR}/${b}/stats.txt"
    do
        if [ -f "$cand" ]; then
            echo "$cand"
            return
        fi
    done
    echo ""
}

for bench in "${WORKLOADS[@]}"; do
    log=$(find_log "$bench")
    stats=$(find_stats "$bench")

    b_val=""
    a_val=""
    red_val=""
    pkts=""
    dur=""
    status="NOT FOUND"

    # 1. Parse from log if present
    if [ -n "$log" ] && [ -f "$log" ]; then
        # Check if banner exists in log
        b_val=$(grep -oE "Switching Probability Before \(FIFO\):[[:space:]]*[0-9.]+" "$log" | awk '{print $NF}' | tail -n 1)
        a_val=$(grep -oE "Switching Probability After \(OOO\):[[:space:]]*[0-9.]+" "$log" | awk '{print $NF}' | tail -n 1)
        red_val=$(grep -oE "Switching Activity Reduction:[[:space:]]*[0-9.]+" "$log" | awk '{print $NF}' | tail -n 1)
        pkts=$(grep -oE "Total Injected Packets:[[:space:]]*[0-9]+" "$log" | awk '{print $NF}' | tail -n 1)
        dur=$(grep -oE "completed in [0-9]+h:[0-9]+m:[0-9]+s" "$log" | awk '{print $NF}' | tail -n 1)

        # Fallback to running progress if final banner isn't printed yet
        if [ -z "$b_val" ]; then
            b_val=$(grep -oE "Prob Before \(FIFO\):[[:space:]]*[0-9.]+" "$log" | awk '{print $NF}' | tail -n 1)
            a_val=$(grep -oE "After \(OOO\):[[:space:]]*[0-9.]+" "$log" | awk '{print $NF}' | tail -n 1)
            red_val=$(grep -oE "Reduction:[[:space:]]*[0-9.]+" "$log" | awk '{print $NF}' | tail -n 1)
            [ -n "$b_val" ] && status="IN PROGRESS"
        fi
    fi

    # 2. Parse from stats.txt if log lacked data
    if [ -n "$stats" ] && [ -f "$stats" ]; then
        if [ -z "$b_val" ]; then
            raw_b=$(grep -E "switching_prob_before" "$stats" | awk '{print $2}' | tail -n 1)
            [ -n "$raw_b" ] && b_val=$(awk "BEGIN {printf \"%.2f\", $raw_b * 100.0}")
        fi
        if [ -z "$a_val" ]; then
            raw_a=$(grep -E "switching_prob_after" "$stats" | awk '{print $2}' | tail -n 1)
            [ -n "$raw_a" ] && a_val=$(awk "BEGIN {printf \"%.2f\", $raw_a * 100.0}")
        fi
        if [ -z "$red_val" ]; then
            raw_r=$(grep -E "switching_reduction_percent" "$stats" | awk '{print $2}' | tail -n 1)
            [ -n "$raw_r" ] && red_val=$(awk "BEGIN {printf \"%.2f\", $raw_r}")
        fi
    fi

    # 3. Calculate reduction if before and after exist but reduction string is empty
    if [ -n "$b_val" ] && [ -n "$a_val" ] && [ -z "$red_val" ]; then
        red_val=$(awk "BEGIN {
            b = $b_val; a = $a_val;
            if (b > 0) printf \"%.2f\", ((b - a) / b) * 100.0;
        }")
    fi

    # 4. Determine Status
    if [ -n "$b_val" ] && [ -n "$a_val" ]; then
        if [ -n "$dur" ] || grep -q "Exiting @ tick" "$log" 2>/dev/null; then
            status="SUCCESS"
        else
            status="${status:-SUCCESS}"
        fi
        BEFORE_PCT["$bench"]="${b_val}%"
        AFTER_PCT["$bench"]="${a_val}%"
        if [ -n "$red_val" ]; then
            fmt_red=$(awk "BEGIN { r = $red_val; if (r >= 0) printf \"+%.2f%%\", r; else printf \"%.2f%%\", r; }")
            REDUCTION_PCT["$bench"]="$fmt_red"
            TOTAL_REDUCTION=$(awk "BEGIN { print $TOTAL_REDUCTION + $red_val }")
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        else
            REDUCTION_PCT["$bench"]="N/A"
        fi
    else
        BEFORE_PCT["$bench"]="N/A"
        AFTER_PCT["$bench"]="N/A"
        REDUCTION_PCT["$bench"]="N/A"
        if [ -n "$log" ]; then
            status="INCOMPLETE"
        else
            status="NOT RUN"
        fi
    fi

    DURATION["$bench"]="${dur:-N/A}"
    PACKETS["$bench"]="${pkts:-N/A}"
    BENCH_STATUS["$bench"]="$status"
done

AVG_SUMMARY=""
if [ "$SUCCESS_COUNT" -gt 0 ]; then
    AVG_RED=$(awk "BEGIN { printf \"%+.2f%%\", $TOTAL_REDUCTION / $SUCCESS_COUNT }")
    AVG_SUMMARY="Average Switching Reduction across ${SUCCESS_COUNT} workloads: ${AVG_RED}"
fi

SUMMARY_OUTPUT_FILE="${TARGET_DIR}/ooo_medium_collated_summary.txt"

REPORT=$(cat <<EOF
===========================================================================================================================
            Out-of-Order (Body Flit Reordering) -- Medium Workloads Summary
===========================================================================================================================
 Workloads:          ${WORKLOADS[*]} (PARSEC simmedium)
 Log Directory:      ${TARGET_DIR}
 Generated At:       $(date)
---------------------------------------------------------------------------------------------------------------------------
$(printf "%-16s | %-14s | %-14s | %-18s | %-12s | %-12s | %-12s\n" "Benchmark" "Before (FIFO)" "After (OOO)" "Switching Reduction" "Duration" "Packets" "Status")
$(printf "%-16s-+-%-14s-+-%-14s-+-%-18s-+-%-12s-+-%-12s-+-%-12s\n" "----------------" "--------------" "--------------" "------------------" "------------" "------------" "------------")
$(for bench in "${WORKLOADS[@]}"; do
    printf "%-16s | %-14s | %-14s | %-18s | %-12s | %-12s | %-12s\n" \
        "$bench" \
        "${BEFORE_PCT[$bench]}" \
        "${AFTER_PCT[$bench]}" \
        "${REDUCTION_PCT[$bench]}" \
        "${DURATION[$bench]}" \
        "${PACKETS[$bench]}" \
        "${BENCH_STATUS[$bench]}"
done)
===========================================================================================================================
EOF
)

if [ -n "$AVG_SUMMARY" ]; then
    REPORT="${REPORT}
 ${AVG_SUMMARY}
==========================================================================================================================="
fi

echo "$REPORT" | tee "$SUMMARY_OUTPUT_FILE" 2>/dev/null || echo "$REPORT"
echo ""
echo "[+] Summary successfully saved to: ${SUMMARY_OUTPUT_FILE}"
