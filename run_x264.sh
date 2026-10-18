#!/bin/sh
echo "Boot done"
sleep 2

if [ -d "/home/gem5/parsec-benchmark" ]; then
    PARSEC_DIR="/home/gem5/parsec-benchmark"
else
    PARSEC_DIR="/home/parsec-benchmark"
fi

BENCH_DIR="$PARSEC_DIR/pkgs/apps/x264"
HOOKS_LIB="$PARSEC_DIR/pkgs/libs/hooks/inst/amd64-linux.gcc-hooks/lib"
BINARY="$BENCH_DIR/inst/amd64-linux.gcc-hooks/bin/x264"
INPUT_DIR="$BENCH_DIR/inputs"
OUTPUT_DIR="/home/gem5"
mkdir -p "$OUTPUT_DIR" 2>/dev/null || OUTPUT_DIR="/tmp"

export LD_LIBRARY_PATH=$HOOKS_LIB:$LD_LIBRARY_PATH

# Extract simsmall input archive
tar -xvf $INPUT_DIR/input_simsmall.tar -C $INPUT_DIR

if [ -f "$INPUT_DIR/eledream_640x360_8.y4m" ]; then
    X264_IN="$INPUT_DIR/eledream_640x360_8.y4m"
elif [ -f "$INPUT_DIR/eledream_640x360_32.y4m" ]; then
    X264_IN="$INPUT_DIR/eledream_640x360_32.y4m"
else
    X264_IN="$(ls $INPUT_DIR/*.y4m 2>/dev/null | head -n 1)"
fi

# Pre-warm DRAM page cache in fast KVM mode
cat "$X264_IN" > /dev/null 2>&1

cd $BENCH_DIR

echo "Starting ROI"
/sbin/m5 exit 1

$BINARY --quiet --qp 20 --partitions b8x8,i4x4 --ref 5 --direct auto --b-pyramid --weightb --mixed-refs --no-fast-pskip --me umh --subme 7 --analyse b8x8,i4x4 --threads 4 -o $OUTPUT_DIR/eledream.264 "$X264_IN"

echo "Ending ROI"
/sbin/m5 exit 2
