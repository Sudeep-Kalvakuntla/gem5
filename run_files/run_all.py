import os
import subprocess

# Base directories
GEM5_HOST_DIR = "/mnt/c/Users/LENOVO/Desktop/NoC/noc_power/gem5-23.0.0.1"
PARSEC_BENCHMARK_DIR = "/mnt/c/Users/LENOVO/Desktop/NoC/parsec-benchmark"
OUTPUT_BASE_DIR = "/mnt/d"

# Configuration for remaining 12 PARSEC suites (simsmall inputs, 4 threads)
BENCHMARKS = {
    "blackscholes": {
        "group": "apps",
        "input_tar": "input_simsmall.tar",
        "extract": True,
        "run_cmd": "$BINARY 4 $INPUT_DIR/in_16K.txt $OUTPUT_DIR/prices.txt",
    },
    "bodytrack": {
        "group": "apps",
        "input_tar": "input_simsmall.tar",
        "extract": True,
        "run_cmd": "$BINARY $INPUT_DIR/sequenceB_1 4 1 1000 5 0 4",
    },
    "canneal": {
        "group": "kernels",
        "input_tar": "input_simsmall.tar",
        "extract": True,
        "run_cmd": "$BINARY 4 10000 2000 $INPUT_DIR/100000.nets 32",
    },
    "dedup": {
        "group": "kernels",
        "input_tar": "input_simsmall.tar",
        "extract": True,
        "run_cmd": "$BINARY -c -p -v -t 4 -i $INPUT_DIR/media.dat -o $OUTPUT_DIR/output.dat.ddp",
    },
    "facesim": {
        "group": "apps",
        "input_tar": "input_simsmall.tar",
        "extract": True,
        "run_cmd": "$BINARY -threads 4 -lastframe 1",
    },
    "ferret": {
        "group": "apps",
        "input_tar": "input_simsmall.tar",
        "extract": True,
        "run_cmd": "$BINARY $INPUT_DIR/corel lsh $INPUT_DIR/queries 10 20 4 $OUTPUT_DIR/output.txt",
    },
    "freqmine": {
        "group": "apps",
        "input_tar": "input_simsmall.tar",
        "extract": True,
        "run_cmd": "$BINARY $INPUT_DIR/kosarak_250k.dat 220",
    },
    "raytrace": {
        "group": "apps",
        "input_tar": "input_simsmall.tar",
        "extract": True,
        "run_cmd": "$BINARY $INPUT_DIR/happy_buddha.obj -automove -nthreads 4 -frames 3 -res 480 270",
    },
    "streamcluster": {
        "group": "kernels",
        "input_tar": None,
        "extract": False,
        "run_cmd": "$BINARY 10 20 32 4096 4096 1000 none $OUTPUT_DIR/output.txt 4",
    },
    "swaptions": {
        "group": "apps",
        "input_tar": None,
        "extract": False,
        "run_cmd": "$BINARY -ns 16 -sm 10000 -nt 4",
    },
    "vips": {
        "group": "apps",
        "input_tar": "input_simsmall.tar",
        "extract": True,
        "run_cmd": "$BINARY im_benchmark $INPUT_DIR/pomegranate_1600x1200.v $OUTPUT_DIR/output.v",
    },
    "x264": {
        "group": "apps",
        "input_tar": "input_simsmall.tar",
        "extract": True,
        "run_cmd": "$BINARY --quiet --qp 20 --partitions b8x8,i4x4 --ref 5 --direct auto --b-pyramid --weightb --mixed-refs --no-fast-pskip --me umh --subme 7 --analyse b8x8,i4x4 --threads 4 -o $OUTPUT_DIR/eledream.264 $INPUT_DIR/eledream_640x360_32.y4m",
    },
}

# Shell script template executed inside the guest VM
SH_TEMPLATE = """#!/bin/sh
echo "Boot done"
sleep 2

PARSEC_DIR="/home/gem5/parsec-benchmark"
BENCH_DIR="$PARSEC_DIR/pkgs/{group}/{bench}"
HOOKS_LIB="$PARSEC_DIR/pkgs/libs/hooks/inst/amd64-linux.gcc-hooks/lib"
BINARY="$BENCH_DIR/inst/amd64-linux.gcc-hooks/bin/{bench}"
INPUT_DIR="$BENCH_DIR/inputs"
OUTPUT_DIR="/home/gem5"

export LD_LIBRARY_PATH=$HOOKS_LIB:$LD_LIBRARY_PATH

{extract_cmd}

echo "Starting ROI"
/sbin/m5 exit 1
sleep 1

cd $BENCH_DIR
{run_cmd}

echo "Ending ROI"
/sbin/m5 exit 2
sleep 1
"""

# Step 1: Pre-generate output directories (skip if already present)
print("Checking output directories...")
benchmark_paths = {}
for bench in BENCHMARKS:
    out_dir = os.path.join(OUTPUT_BASE_DIR, f"gem5_output_64bit_{bench}")
    benchmark_paths[bench] = out_dir
    
    if os.path.isdir(out_dir):
        print(f"Skipping creation (already exists): {out_dir}")
    else:
        os.makedirs(out_dir, exist_ok=True)
        print(f"Created: {out_dir}")

print("\nStarting execution loop...\n")

# Step 2: Run all benchmarks sequentially
for bench, config in BENCHMARKS.items():
    print("=" * 50)
    print(f"Starting simulation: {bench}")
    print("=" * 50)

    extract_block = (
        f"tar -xvf $INPUT_DIR/{config['input_tar']} -C $INPUT_DIR"
        if config["extract"]
        else "# No input archive to extract"
    )

    sh_content = SH_TEMPLATE.format(
        group=config["group"],
        bench=bench,
        extract_cmd=extract_block,
        run_cmd=config["run_cmd"],
    )

    sh_filename = f"run_{bench}.sh"
    sh_path = os.path.join(GEM5_HOST_DIR, sh_filename)

    with open(sh_path, "w", newline="\n") as f:
        f.write(sh_content)

    output_dir = benchmark_paths[bench]
    log_file_path = os.path.join(output_dir, "simulation.log")

    docker_cmd = [
        "docker", "run", "--rm",
        "--privileged",
        "--cap-add=SYS_ADMIN",
        "--cap-add=SYS_PTRACE",
        "--device=/dev/kvm",
        "-e", "TERM=xterm",
        "-e", "TZ=UTC",
        "-v", f"{GEM5_HOST_DIR}:/gem5",
        "-v", f"{PARSEC_BENCHMARK_DIR}:/parsec-benchmark",
        "-v", f"{output_dir}:/output",
        "-v", "/etc/localtime:/etc/localtime:ro",
        "-w", "/gem5",
        "-e", "LANG=C.UTF-8",
        "-e", "LC_ALL=C.UTF-8",
        "ghcr.io/gem5/ubuntu-22.04_all-dependencies:v23-0",
        "./build/X86_MESI_TWO_LEVEL/gem5.opt",
        "-d", "/output",
        "--debug-flags=OOO",
        "configs/deprecated/example/fskvm.py",
        "--cpu-type=X86KvmCPU",
        "--num-cpus=4",
        "--ruby",
        "--network=garnet",
        "--topology=Mesh_XY",
        "--mesh-rows=2",
        "--link-width-bits=64",
        "--num-dirs=4",
        "--num-l2caches=4",
        "--kernel=/parsec-benchmark/x86-linux-kernel-5.4.49",
        "--disk-image=/parsec-benchmark/parsec.img",
        f"--script=/gem5/{sh_filename}",
    ]

    with open(log_file_path, "w") as log_file:
        subprocess.run(docker_cmd, stdout=log_file, stderr=subprocess.STDOUT)

    print(f"Finished {bench}. Output written to {output_dir}\n")