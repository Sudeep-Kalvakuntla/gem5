#!/bin/sh
echo "Boot done"
sleep 2

PARSEC_DIR="/home/gem5/parsec-benchmark"
BENCH_DIR="$PARSEC_DIR/pkgs/kernels/canneal"
HOOKS_LIB="$PARSEC_DIR/pkgs/libs/hooks/inst/amd64-linux.gcc-hooks/lib"
BINARY="$BENCH_DIR/inst/amd64-linux.gcc-hooks/bin/canneal"
INPUT_DIR="$BENCH_DIR/inputs"
OUTPUT_DIR="/home/gem5"

export LD_LIBRARY_PATH=$HOOKS_LIB:$LD_LIBRARY_PATH

tar -xvf $INPUT_DIR/input_simsmall.tar -C $INPUT_DIR

echo "Starting ROI"
/sbin/m5 exit 1
sleep 1

cd $BENCH_DIR
$BINARY 4 10000 2000 $INPUT_DIR/100000.nets 32

echo "Ending ROI"
/sbin/m5 exit 2
sleep 1
