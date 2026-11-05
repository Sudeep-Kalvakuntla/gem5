#!/bin/bash
# ==============================================================================
# Script: collate_oip_small_stats.sh
# Description: Collates and summarizes simulation statistics comparing Baseline
#              (gem5 default) vs Order-is-Power (OIP) for small workloads.
# Usage:
#   ./collate_oip_small_stats.sh [before_dir] [after_dir] [workloads...]
#   or auto-detect:
#   ./collate_oip_small_stats.sh
# Examples:
#   ./collate_oip_small_stats.sh
#   ./collate_oip_small_stats.sh ~/Low-Power/outputs/gem5_OIP/before_vc6/small ~/Low-Power/outputs/gem5_OIP/oip_vc6/small
#   ./collate_oip_small_stats.sh /output/before_vc6/small /output/oip_vc6/small
# ==============================================================================

set -uo pipefail

BEFORE_IN="${1:-}"
AFTER_IN="${2:-}"

# Expand tildes if passed literally
BEFORE_IN="${BEFORE_IN/#\~/$HOME}"
AFTER_IN="${AFTER_IN/#\~/$HOME}"

# Auto-detect directories if not explicitly provided
if [ -z "$BEFORE_IN" ] || [ -z "$AFTER_IN" ]; then
    # If single parent directory provided
    if [ -n "$BEFORE_IN" ] && [ -d "$BEFORE_IN" ]; then
        PARENT="$BEFORE_IN"
        if [ -d "${PARENT}/before_vc6/small" ] && [ -d "${PARENT}/oip_vc6/small" ]; then
            BEFORE_DIR="${PARENT}/before_vc6/small"
            AFTER_DIR="${PARENT}/oip_vc6/small"
        elif [ -d "${PARENT}/before/small" ] && [ -d "${PARENT}/small" ]; then
            BEFORE_DIR="${PARENT}/before/small"
            AFTER_DIR="${PARENT}/small"
        else
            BEFORE_DIR="${PARENT}"
            AFTER_DIR="${PARENT}"
        fi
    else
        # Search candidate locations
        CANDIDATES_BEFORE=(
            "/output/before_vc6/small"
            "${HOME}/Low-Power/outputs/gem5_OIP/before_vc6/small"
            "/output/before/small"
            "${HOME}/Low-Power/outputs/gem5_OIP/before/small"
            "./outputs/gem5_OIP/before_vc6/small"
            "./output/before_vc6/small"
            "./before_vc6/small"
        )
        CANDIDATES_AFTER=(
            "/output/oip_vc6/small"
            "${HOME}/Low-Power/outputs/gem5_OIP/oip_vc6/small"
            "/output/small"
            "${HOME}/Low-Power/outputs/gem5_OIP/small"
            "./outputs/gem5_OIP/oip_vc6/small"
            "./output/oip_vc6/small"
            "./oip_vc6/small"
        )

        BEFORE_DIR=""
        for cb in "${CANDIDATES_BEFORE[@]}"; do
            if [ -d "$cb" ]; then
                BEFORE_DIR="$cb"
                break
            fi
        done

        AFTER_DIR=""
        for ca in "${CANDIDATES_AFTER[@]}"; do
            if [ -d "$ca" ]; then
                AFTER_DIR="$ca"
                break
            fi
        done

        # Fallback defaults
        [ -z "$BEFORE_DIR" ] && BEFORE_DIR="/output/before_vc6/small"
        [ -z "$AFTER_DIR" ] && AFTER_DIR="/output/oip_vc6/small"
    fi
else
    BEFORE_DIR="$BEFORE_IN"
    AFTER_DIR="$AFTER_IN"
fi

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

# Parse custom workloads if provided
if [ $# -gt 2 ]; then
    shift 2
    WORKLOADS=("$@")
else
    WORKLOADS=("${DEFAULT_WORKLOADS[@]}")
fi

declare -A BEFORE_PCT
declare -A AFTER_PCT
declare -A BEFORE_DUR
declare -A AFTER_DUR
declare -A REDUCTION_PCT
declare -A BENCH_STATUS

# Helper to find log file
find_log() {
    local dir="$1"
    local b="$2"
    for cand in \
        "${dir}/simulation-${b}-small.log" \
        "${dir}/simulation-${b}.log" \
        "${dir}/${b}_small/system.pc.com_1.device" \
        "${dir}/${b}/system.pc.com_1.device" \
        "${dir}/${b}.log"
    do
        if [ -f "$cand" ]; then
            echo "$cand"
            return
        fi
    done
    echo ""
}

# Helper to find stats file
find_stats() {
    local dir="$1"
    local b="$2"
    for cand in \
        "${dir}/stats-${b}-small.txt" \
        "${dir}/stats-${b}.txt" \
        "${dir}/${b}_small/stats.txt" \
        "${dir}/${b}/stats.txt"
    do
        if [ -f "$cand" ]; then
            echo "$cand"
            return
        fi
    done
    echo ""
}

# Helper to extract switching activity
extract_switching() {
    local log="$1"
    local stats="$2"
    local pct=""

    if [ -n "$log" ] && [ -f "$log" ]; then
        pct=$(grep -oE "Average Link Switching Activity:[[:space:]]*[0-9.]+" "$log" | awk '{print $NF}' | tail -n 1)
        if [ -z "$pct" ]; then
            pct=$(grep -oE "Running Avg Link Switching:[[:space:]]*[0-9.]+" "$log" | awk '{print $NF}' | tail -n 1)
        fi
    fi
    if [ -z "$pct" ] && [ -n "$stats" ] && [ -f "$stats" ]; then
        local raw=$(grep -E "avg_link_switching_probability" "$stats" | awk '{print $2}' | tail -n 1)
        if [ -n "$raw" ]; then
            pct=$(awk "BEGIN {printf \"%.2f\", $raw * 100.0}")
        fi
    fi
    echo "${pct:-N/A}"
}

# Helper to extract duration
extract_duration() {
    local log="$1"
    local dur=""
    if [ -n "$log" ] && [ -f "$log" ]; then
        dur=$(grep -oE "completed in [0-9]+h:[0-9]+m:[0-9]+s" "$log" | awk '{print $NF}' | tail -n 1)
    fi
    echo "${dur:-N/A}"
}

TOTAL_REDUCTION=0
SUCCESS_COUNT=0

for bench in "${WORKLOADS[@]}"; do
    b_log=$(find_log "$BEFORE_DIR" "$bench")
    b_stats=$(find_stats "$BEFORE_DIR" "$bench")

    a_log=$(find_log "$AFTER_DIR" "$bench")
    a_stats=$(find_stats "$AFTER_DIR" "$bench")

    b_val=$(extract_switching "$b_log" "$b_stats")
    a_val=$(extract_switching "$a_log" "$a_stats")
    b_dur=$(extract_duration "$b_log")
    a_dur=$(extract_duration "$a_log")

    BEFORE_PCT["$bench"]="$b_val"
    AFTER_PCT["$bench"]="$a_val"
    BEFORE_DUR["$bench"]="$b_dur"
    AFTER_DUR["$bench"]="$a_dur"

    if [ "$b_val" != "N/A" ] && [ "$a_val" != "N/A" ]; then
        red_num=$(awk "BEGIN {
            b = $b_val; a = $a_val;
            if (b > 0) printf \"%.2f\", ((b - a) / b) * 100.0;
        }")
        fmt_red=$(awk "BEGIN {
            r = $red_num;
            if (r >= 0) printf \"+%.2f%%\", r;
            else printf \"%.2f%%\", r;
        }")
        REDUCTION_PCT["$bench"]="$fmt_red"
        BENCH_STATUS["$bench"]="SUCCESS"

        TOTAL_REDUCTION=$(awk "BEGIN { print $TOTAL_REDUCTION + $red_num }")
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    elif [ "$b_val" != "N/A" ] && [ "$a_val" == "N/A" ]; then
        REDUCTION_PCT["$bench"]="N/A"
        if [ -n "$a_log" ]; then
            BENCH_STATUS["$bench"]="AFTER RUNNING"
        else
            BENCH_STATUS["$bench"]="AWAITING AFTER"
        fi
    elif [ "$b_val" == "N/A" ] && [ "$a_val" != "N/A" ]; then
        REDUCTION_PCT["$bench"]="N/A"
        BENCH_STATUS["$bench"]="AWAITING BEFORE"
    else
        REDUCTION_PCT["$bench"]="N/A"
        BENCH_STATUS["$bench"]="NOT RUN"
    fi
done

AVG_SUMMARY=""
if [ "$SUCCESS_COUNT" -gt 0 ]; then
    AVG_RED=$(awk "BEGIN {
        r = $TOTAL_REDUCTION / $SUCCESS_COUNT;
        if (r >= 0) printf \"+%.2f%%\", r;
        else printf \"%.2f%%\", r;
    }")
    AVG_SUMMARY="Average Switching Activity Reduction across ${SUCCESS_COUNT} workloads: ${AVG_RED}"
fi

# Determine summary save file
SUMMARY_FILE="${AFTER_DIR}/oip_vs_before_small_summary.txt"
if [ ! -d "$AFTER_DIR" ]; then
    SUMMARY_FILE="./oip_vs_before_small_summary.txt"
fi

REPORT=$(cat <<EOF
===========================================================================================================================
            Order-is-Power (OIP) vs. Baseline (gem5 Default) -- Small Workloads Summary
===========================================================================================================================
 Workloads:          ${WORKLOADS[*]} (PARSEC simsmall)
 Baseline (Before):  ${BEFORE_DIR}
 Order-is-Power (OIP): ${AFTER_DIR}
 Generated At:       $(date)
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
EOF
)

if [ -n "$AVG_SUMMARY" ]; then
    REPORT="${REPORT}
 ${AVG_SUMMARY}
==========================================================================================================================="
fi

echo "$REPORT" | tee "$SUMMARY_FILE" 2>/dev/null || echo "$REPORT"
echo ""
echo "[+] Summary table successfully generated."
[ -f "$SUMMARY_FILE" ] && echo "[+] Saved to: ${SUMMARY_FILE}"
