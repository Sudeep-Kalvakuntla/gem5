#!/bin/sh

echo "Boot done"
sleep 2

# Define paths based on the common PARSEC image structure
PARSEC_DIR="/home/gem5/parsec-benchmark"
BENCH_DIR="$PARSEC_DIR/pkgs/apps/blackscholes"
HOOKS_LIB="$PARSEC_DIR/pkgs/libs/hooks/inst/amd64-linux.gcc-hooks/lib"
BINARY="$BENCH_DIR/inst/amd64-linux.gcc-hooks/bin/blackscholes"
INPUT_DIR="/home/gem5/parsec-benchmark/pkgs/apps/blackscholes/inputs"
INPUT="$BENCH_DIR/inputs/in_4.txt"
OUTPUT="out.txt" # This will be created in the guest's home directory
# Set the library path required for PARSEC hooks
export LD_LIBRARY_PATH=$HOOKS_LIB:$LD_LIBRARY_PATH

# ROI CODE STARTS HERE
# echo "Hello World from blackscholes!" > /root/roi.log


#tar -xvf $INPUT_DIR/input_native.tar -C $INPUT_DIR
#tar -xvf $INPUT_DIR/input_simdev.tar -C $INPUT_DIR
#tar -xvf $INPUT_DIR/input_simlarge.tar -C $INPUT_DIR
#tar -xvf $INPUT_DIR/input_simmedium.tar -C $INPUT_DIR
#tar -xvf $INPUT_DIR/input_simsmall.tar -C $INPUT_DIR        # in_4K.txt is in this tarball
tar -xvf $INPUT_DIR/input_test.tar -C $INPUT_DIR           # in_4.txt is in this tarball

echo "Starting ROI"
/sbin/m5 exit 1
sleep 1

# echo "Running blackscholes..." > /root/roi.log
# $BINARY 4 $INPUT $OUTPUT >> /root/roi.log 2>&1
# echo "Finished blackscholes" >> /root/roi.log
# cat /root/roi.log

# Execute blackscholes (using 4 threads, as in your original command)
$BINARY 4 $INPUT $OUTPUT

# ROI CODE ENDS HERE

echo "Ending ROI"
/sbin/m5 exit 2
sleep 1
