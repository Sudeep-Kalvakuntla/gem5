#!/bin/sh
echo "Boot done"
sleep 2

if [ -d "/home/gem5/parsec-benchmark" ]; then
    PARSEC_DIR="/home/gem5/parsec-benchmark"
else
    PARSEC_DIR="/home/parsec-benchmark"
fi

BENCH_DIR="$PARSEC_DIR/pkgs/apps/swaptions"
HOOKS_LIB="$PARSEC_DIR/pkgs/libs/hooks/inst/amd64-linux.gcc-hooks/lib"
BINARY="$BENCH_DIR/inst/amd64-linux.gcc-hooks/bin/swaptions"
INPUT_DIR="$BENCH_DIR/inputs"
OUTPUT_DIR="/home/gem5"
mkdir -p "$OUTPUT_DIR" 2>/dev/null || OUTPUT_DIR="/tmp"

export LD_LIBRARY_PATH=$HOOKS_LIB:$LD_LIBRARY_PATH

# No input archive to extract for swaptions

cd $BENCH_DIR

echo "Starting ROI"
/sbin/m5 exit 1

$BINARY -ns 16 -sm 10000 -nt 4

echo "Ending ROI"
/sbin/m5 exit 2
