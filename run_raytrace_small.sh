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

# Extract simsmall input archive (contains happy_buddha.obj)
tar -xvf $INPUT_DIR/input_simsmall.tar -C $INPUT_DIR

# Pre-warm DRAM page cache in fast KVM mode
cat $INPUT_DIR/happy_buddha.obj > /dev/null 2>&1
find $INPUT_DIR -type f -exec cat {} + > /dev/null 2>&1

cd $BENCH_DIR

echo "Starting ROI"
/sbin/m5 exit 1

# Launch raytrace in background and monitor for completion.
# PARSEC raytrace has a known bug where worker threads hang in pthread_join
# during post-ROI destructor cleanup after printing "Done".
rm -f /tmp/rt.log
$BINARY $INPUT_DIR/happy_buddha.obj -automove -nthreads 4 -frames 3 -res 480 270 > /tmp/rt.log 2>&1 &
B_PID=$!

while kill -0 $B_PID 2>/dev/null; do
    if grep -q "Done" /tmp/rt.log 2>/dev/null; then
        cat /tmp/rt.log
        sleep 1
        kill -9 $B_PID 2>/dev/null || true
        break
    fi
    sleep 1
done

if [ -f /tmp/rt.log ]; then
    cat /tmp/rt.log
fi

echo "Ending ROI"
/sbin/m5 exit 2
