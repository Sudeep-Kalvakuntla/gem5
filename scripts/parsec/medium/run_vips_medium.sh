#!/bin/sh
echo "Boot done"
sleep 2

if [ -d "/home/gem5/parsec-benchmark" ]; then
    PARSEC_DIR="/home/gem5/parsec-benchmark"
else
    PARSEC_DIR="/home/parsec-benchmark"
fi

BENCH_DIR="$PARSEC_DIR/pkgs/apps/vips"
HOOKS_LIB="$PARSEC_DIR/pkgs/libs/hooks/inst/amd64-linux.gcc-hooks/lib"
BINARY="$BENCH_DIR/inst/amd64-linux.gcc-hooks/bin/vips"
INPUT_DIR="$BENCH_DIR/inputs"
OUTPUT_DIR="/home/gem5"
mkdir -p "$OUTPUT_DIR" 2>/dev/null || OUTPUT_DIR="/tmp"

export LD_LIBRARY_PATH=$HOOKS_LIB:$LD_LIBRARY_PATH

# Extract simmedium input archive
tar -xvf $INPUT_DIR/input_simmedium.tar -C $INPUT_DIR

if [ -f "$INPUT_DIR/vulture_2336x2336.v" ]; then
    VIPS_IN="$INPUT_DIR/vulture_2336x2336.v"
elif [ -f "$INPUT_DIR/pomegranate_2600x2000.v" ]; then
    VIPS_IN="$INPUT_DIR/pomegranate_2600x2000.v"
else
    VIPS_IN="$(ls $INPUT_DIR/*.v 2>/dev/null | head -n 1)"
fi

# Pre-warm DRAM page cache in fast KVM mode
cat "$VIPS_IN" > /dev/null 2>&1

cd $BENCH_DIR

echo "Starting ROI"
/sbin/m5 exit 1

$BINARY im_benchmark "$VIPS_IN" $OUTPUT_DIR/output.v

echo "Ending ROI"
/sbin/m5 exit 2
