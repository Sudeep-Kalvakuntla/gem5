#!/bin/bash
# ==============================================================================
# Script: run_all_small.sh
# Description: Sequentially executes all 13 PARSEC small workloads in gem5
#              within the Docker container environment.
#              Stores outputs into a dedicated subdirectory inside gem5_OIP (/output/small)
# Workloads (13 total):
#   blackscholes, bodytrack, canneal, dedup, facesim, ferret, fluidanimate,
#   freqmine, raytrace, streamcluster, swaptions, vips, x264
# ==============================================================================

set -u

export PYTHONUNBUFFERED=1
STDBUF=""
command -v stdbuf >/dev/null 2>&1 && STDBUF="stdbuf -oL -eL"

# Configuration & Paths
ROOT_DIR="/gem5"
if [ ! -d "$ROOT_DIR" ]; then
    ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi

GEM5_BIN="${ROOT_DIR}/build/X86_MESI_TWO_LEVEL/gem5.opt"
if [ ! -x "$GEM5_BIN" ] && [ -x "./build/X86_MESI_TWO_LEVEL/gem5.opt" ]; then
    GEM5_BIN="./build/X86_MESI_TWO_LEVEL/gem5.opt"
fi

CONFIG="${ROOT_DIR}/configs/deprecated/example/fskvm.py"
if [ ! -f "$CONFIG" ] && [ -f "configs/deprecated/example/fskvm.py" ]; then
    CONFIG="configs/deprecated/example/fskvm.py"
fi

KERNEL="/parsec-benchmark/x86-linux-kernel-5.4.49"
DISK_IMAGE="/parsec-benchmark/parsec.img"

# Dedicated baseline output directory (/output/before/small -> ~/Low-Power/outputs/gem5_OIP/before/small/)
: "${OUTPUT_DIR:=/output/before/small}"
: "${VCS_PER_VNET:=4}"
mkdir -p "$OUTPUT_DIR"

# All 13 PARSEC small workloads
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

# Allow passing custom subset of workloads via CLI: ./run_all_small.sh blackscholes canneal
if [ $# -gt 0 ]; then
    WORKLOADS=("$@")
else
    WORKLOADS=("${DEFAULT_WORKLOADS[@]}")
fi

TOTAL_BENCHMARKS=${#WORKLOADS[@]}
declare -A BENCH_STATUS
declare -A BENCH_DURATION

echo "========================================================================"
echo " Starting PARSEC Small Workload Batch Execution"
echo " Total benchmarks queued: ${TOTAL_BENCHMARKS}"
echo " Workloads: ${WORKLOADS[*]}"
echo " Start time: $(date)"
echo " Output directory: ${OUTPUT_DIR}"
echo "========================================================================"

INDEX=0
for bench in "${WORKLOADS[@]}"; do
    INDEX=$((INDEX + 1))
    
    # Locate workload script (checks small/ subfolder first, then legacy locations)
    SCRIPT=""
    for candidate in \
        "${ROOT_DIR}/scripts/parsec/small/run_${bench}_small.sh" \
        "${ROOT_DIR}/scripts/parsec/small/run_${bench}.sh" \
        "${ROOT_DIR}/run_${bench}_small.sh" \
        "${ROOT_DIR}/run_${bench}.sh" \
        "./scripts/parsec/small/run_${bench}_small.sh" \
        "./scripts/parsec/small/run_${bench}.sh" \
        "./run_${bench}_small.sh" \
        "./run_${bench}.sh"
    do
        if [ -f "$candidate" ]; then
            SCRIPT="$candidate"
            break
        fi
    done

    if [ -z "$SCRIPT" ] || [ ! -f "$SCRIPT" ]; then
        echo "[-] ERROR: Script not found for ${bench}: searched small/ and root. Skipping."
        BENCH_STATUS["$bench"]="SCRIPT_NOT_FOUND"
        BENCH_DURATION["$bench"]="0s"
        continue
    fi

    LOG_FILE="${OUTPUT_DIR}/simulation-${bench}-small.log"
    BENCH_OUTDIR="${OUTPUT_DIR}/${bench}_small"
    mkdir -p "$BENCH_OUTDIR"

    echo ""
    echo "------------------------------------------------------------------------"
    echo " [${INDEX}/${TOTAL_BENCHMARKS}] Running: ${bench} (simsmall)"
    echo " Script: ${SCRIPT}"
    echo " Log file: ${LOG_FILE}"
    echo " Started: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "------------------------------------------------------------------------"

    START_SEC=$(date +%s)

    # Execute gem5 simulation targeting /output/small
    $STDBUF "$GEM5_BIN" \
        -d "$OUTPUT_DIR" \
        --debug-flags=OOO \
        "$CONFIG" \
        --cpu-type=X86KvmCPU \
        --num-cpus=4 \
        --ruby \
        --network=garnet \
        --topology=Mesh_XY \
        --mesh-rows=2 \
        --link-width-bits=64 \
        --num-dirs=4 \
        --vcs-per-vnet="$VCS_PER_VNET" \
        --num-l2caches=4 \
        --kernel="$KERNEL" \
        --disk-image="$DISK_IMAGE" \
        --script="$SCRIPT" 2>&1 | tee "$LOG_FILE"

    GEM5_EXIT=${PIPESTATUS[0]}
    END_SEC=$(date +%s)
    ELAPSED=$((END_SEC - START_SEC))
    HOURS=$((ELAPSED / 3600))
    MINUTES=$(((ELAPSED % 3600) / 60))
    SECONDS=$((ELAPSED % 60))
    DURATION_FMT="$(printf '%02dh:%02dm:%02ds' $HOURS $MINUTES $SECONDS)"
    BENCH_DURATION["$bench"]="$DURATION_FMT"

    # Preserve benchmark specific outputs
    if [ -f "${OUTPUT_DIR}/stats.txt" ]; then
        cp "${OUTPUT_DIR}/stats.txt" "${OUTPUT_DIR}/stats-${bench}-small.txt" 2>/dev/null || true
        cp "${OUTPUT_DIR}/stats.txt" "${BENCH_OUTDIR}/stats.txt" 2>/dev/null || true
    fi
    if [ -f "${OUTPUT_DIR}/config.ini" ]; then
        cp "${OUTPUT_DIR}/config.ini" "${BENCH_OUTDIR}/config.ini" 2>/dev/null || true
    fi
    if [ -f "${OUTPUT_DIR}/config.json" ]; then
        cp "${OUTPUT_DIR}/config.json" "${BENCH_OUTDIR}/config.json" 2>/dev/null || true
    fi
    if [ -f "${OUTPUT_DIR}/system.pc.com_1.device" ]; then
        cp "${OUTPUT_DIR}/system.pc.com_1.device" "${BENCH_OUTDIR}/system.pc.com_1.device" 2>/dev/null || true
    fi

    # Verify run status
    if [ $GEM5_EXIT -eq 0 ]; then
        echo "[+] [${INDEX}/${TOTAL_BENCHMARKS}] SUCCESS: ${bench} completed in ${DURATION_FMT}"
        BENCH_STATUS["$bench"]="SUCCESS"
    else
        echo "[-] [${INDEX}/${TOTAL_BENCHMARKS}] FAILED: ${bench} exited with error code ${GEM5_EXIT} after ${DURATION_FMT}"
        BENCH_STATUS["$bench"]="FAILED (code $GEM5_EXIT)"
    fi
done

echo ""
echo "========================================================================"
echo " PARSEC Small Batch Execution Summary"
echo " Finished at: $(date)"
echo "========================================================================"
printf "%-20s %-15s %-15s\n" "Benchmark" "Status" "Duration"
printf "%-20s %-15s %-15s\n" "--------------------" "---------------" "---------------"
for bench in "${WORKLOADS[@]}"; do
    printf "%-20s %-15s %-15s\n" "$bench" "${BENCH_STATUS[$bench]:-UNKNOWN}" "${BENCH_DURATION[$bench]:-UNKNOWN}"
done
echo "========================================================================"
