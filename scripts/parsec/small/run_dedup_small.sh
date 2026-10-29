#!/bin/sh
echo "Boot done"
sleep 2

if [ -d "/home/gem5/parsec-benchmark" ]; then
    PARSEC_DIR="/home/gem5/parsec-benchmark"
else
    PARSEC_DIR="/home/parsec-benchmark"
fi

BENCH_DIR="$PARSEC_DIR/pkgs/kernels/dedup"
HOOKS_LIB="$PARSEC_DIR/pkgs/libs/hooks/inst/amd64-linux.gcc-hooks/lib"
BINARY="$BENCH_DIR/inst/amd64-linux.gcc-hooks/bin/dedup"
INPUT_DIR="$BENCH_DIR/inputs"
OUTPUT_DIR="/home/gem5"
mkdir -p "$OUTPUT_DIR" 2>/dev/null || OUTPUT_DIR="/tmp"

export LD_LIBRARY_PATH=$HOOKS_LIB:$LD_LIBRARY_PATH

# Extract simsmall input archive
tar -xvf $INPUT_DIR/input_simsmall.tar -C $INPUT_DIR

# Pre-warm DRAM page cache in fast KVM mode
cat $INPUT_DIR/media.dat > /dev/null 2>&1

cd $BENCH_DIR

echo "Starting ROI"
/sbin/m5 exit 1

$BINARY -c -p -v -t 4 -i $INPUT_DIR/media.dat -o $OUTPUT_DIR/output.dat.ddp

echo "Ending ROI"
/sbin/m5 exit 2
