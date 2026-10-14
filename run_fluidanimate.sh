#!/bin/sh

echo "Boot done"
sleep 2

# Define paths based on the common PARSEC image structure
PARSEC_DIR="/home/gem5/parsec-benchmark"
BENCH_DIR="$PARSEC_DIR/pkgs/apps/fluidanimate"
HOOKS_LIB="$PARSEC_DIR/pkgs/libs/hooks/inst/amd64-linux.gcc-hooks/lib"
BINARY="$BENCH_DIR/inst/amd64-linux.gcc-hooks/bin/fluidanimate"
INPUT_DIR="$BENCH_DIR/inputs"
INPUT="$INPUT_DIR/in_35K.fluid"
OUTPUT="out.fluid" # This will be created in the guest's home directory

# Set the library path required for PARSEC hooks
export LD_LIBRARY_PATH=$HOOKS_LIB:$LD_LIBRARY_PATH

# Extract the test input configuration (contains in_5K.fluid)
tar -xvf $INPUT_DIR/input_simsmall.tar -C $INPUT_DIR

echo "Starting ROI"
/sbin/m5 exit 1
sleep 1

# Execute fluidanimate 
# Arguments: <thread_count> <framenums> <input_file> <output_file>
$BINARY 4 5 $INPUT $OUTPUT

echo "Ending ROI"
/sbin/m5 exit 2
sleep 1