#!/bin/sh
echo "Boot done"
sleep 2

PARSEC_DIR="/home/gem5/parsec-benchmark"
BENCH_DIR="$PARSEC_DIR/pkgs/apps/x264"
HOOKS_LIB="$PARSEC_DIR/pkgs/libs/hooks/inst/amd64-linux.gcc-hooks/lib"
BINARY="$BENCH_DIR/inst/amd64-linux.gcc-hooks/bin/x264"
INPUT_DIR="$BENCH_DIR/inputs"
OUTPUT_DIR="/home/gem5"

export LD_LIBRARY_PATH=$HOOKS_LIB:$LD_LIBRARY_PATH

tar -xvf $INPUT_DIR/input_simsmall.tar -C $INPUT_DIR

echo "Starting ROI"
/sbin/m5 exit 1
sleep 1

cd $BENCH_DIR
$BINARY --quiet --qp 20 --partitions b8x8,i4x4 --ref 5 --direct auto --b-pyramid --weightb --mixed-refs --no-fast-pskip --me umh --subme 7 --analyse b8x8,i4x4 --threads 4 -o $OUTPUT_DIR/eledream.264 $INPUT_DIR/eledream_640x360_32.y4m

echo "Ending ROI"
/sbin/m5 exit 2
sleep 1
