#!/bin/sh
echo "Boot done"
sleep 2

if [ -d "/home/gem5/parsec-benchmark" ]; then
    PARSEC_DIR="/home/gem5/parsec-benchmark"
else
    PARSEC_DIR="/home/parsec-benchmark"
fi

BENCH_DIR="$PARSEC_DIR/pkgs/apps/blackscholes"
HOOKS_LIB="$PARSEC_DIR/pkgs/libs/hooks/inst/amd64-linux.gcc-hooks/lib"
BINARY="$BENCH_DIR/inst/amd64-linux.gcc-hooks/bin/blackscholes"
INPUT_DIR="$BENCH_DIR/inputs"
OUTPUT_DIR="/home/gem5"
mkdir -p "$OUTPUT_DIR" 2>/dev/null || OUTPUT_DIR="/tmp"

export LD_LIBRARY_PATH=$HOOKS_LIB:$LD_LIBRARY_PATH

tar -xvf $INPUT_DIR/input_simsmall.tar -C $INPUT_DIR

# Pre-warm DRAM page cache in fast KVM mode (eliminates disk I/O latency)
cat $INPUT_DIR/in_4K.txt > /dev/null 2>&1

cd $BENCH_DIR

# Launch Blackscholes:
# Internal PARSEC hooks (m5_work_begin/end) will automatically trigger
# ROI START and ROI END strictly around the multi-threaded pricing calculation.
$BINARY 4 $INPUT_DIR/in_4K.txt $OUTPUT_DIR/prices.txt

# Fallback exit
/sbin/m5 exit 2
