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

if [ -x "$BENCH_DIR/inst/amd64-linux.gcc/bin/x264" ]; then
    BINARY="$BENCH_DIR/inst/amd64-linux.gcc/bin/x264"
elif [ -x "$BENCH_DIR/inst/amd64-linux.gcc-hooks/bin/x264" ]; then
    BINARY="$BENCH_DIR/inst/amd64-linux.gcc-hooks/bin/x264"
else
    BINARY="$(find $BENCH_DIR -name x264 -type f -perm -111 2>/dev/null | head -n 1)"
fi

INPUT_DIR="$BENCH_DIR/inputs"
OUTPUT_DIR="/home/gem5"
mkdir -p "$OUTPUT_DIR" 2>/dev/null || OUTPUT_DIR="/tmp"

export LD_LIBRARY_PATH=$HOOKS_LIB:$LD_LIBRARY_PATH

# Extract simmedium input archive (contains eledream_640x360_32.y4m)
tar -xvf $INPUT_DIR/input_simmedium.tar -C $INPUT_DIR

# Pre-warm DRAM page cache in fast KVM mode
cat $INPUT_DIR/eledream_640x360_32.y4m > /dev/null 2>&1

cd $BENCH_DIR
rm -f "$OUTPUT_DIR/eledream.264"
ulimit -s unlimited 2>/dev/null || ulimit -s 65536 2>/dev/null || true

echo "Starting ROI"
/sbin/m5 exit 1

$BINARY --quiet --qp 20 --partitions b8x8,i4x4 --ref 5 --direct auto --weightb --mixed-refs --no-fast-pskip --me umh --subme 7 --threads 4 -o $OUTPUT_DIR/eledream.264 $INPUT_DIR/eledream_640x360_32.y4m

echo "Ending ROI"
/sbin/m5 exit 2

