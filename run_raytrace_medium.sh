#!/bin/sh
echo "Boot done"
sleep 2

if [ -d "/home/gem5/parsec-benchmark" ]; then
    PARSEC_DIR="/home/gem5/parsec-benchmark"
else
    PARSEC_DIR="/home/parsec-benchmark"
fi

BENCH_DIR="$PARSEC_DIR/pkgs/apps/raytrace"
HOOKS_LIB="$PARSEC_DIR/pkgs/libs/hooks/inst/amd64-linux.gcc-hooks/lib"

if [ -x "$BENCH_DIR/inst/amd64-linux.gcc-hooks/bin/raytrace" ]; then
    BINARY="$BENCH_DIR/inst/amd64-linux.gcc-hooks/bin/raytrace"
else
    BINARY="$BENCH_DIR/inst/amd64-linux.gcc-hooks/bin/rtview"
fi

INPUT_DIR="$BENCH_DIR/inputs"
OUTPUT_DIR="/home/gem5"
mkdir -p "$OUTPUT_DIR" 2>/dev/null || OUTPUT_DIR="/tmp"

export LD_LIBRARY_PATH=$HOOKS_LIB:$LD_LIBRARY_PATH

# Extract simmedium input archive (contains happy_buddha.obj)
tar -xvf $INPUT_DIR/input_simmedium.tar -C $INPUT_DIR

# Pre-warm DRAM page cache in fast KVM mode
cat $INPUT_DIR/happy_buddha.obj > /dev/null 2>&1
find $INPUT_DIR -type f -exec cat {} + > /dev/null 2>&1

cd $BENCH_DIR

echo "Starting ROI"
/sbin/m5 exit 1

$BINARY $INPUT_DIR/happy_buddha.obj -automove -nthreads 4 -frames 3 -res 960 540

echo "Ending ROI"
/sbin/m5 exit 2
