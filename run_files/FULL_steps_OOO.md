**// Run docker in WSL2 Output to D drive/gem5\_output**

docker run --rm \
  --privileged \
  --cap-add=SYS_ADMIN \
  --cap-add=SYS_PTRACE \
  --device=/dev/kvm \
  -e TERM=xterm \
  -e TZ="$(cat /etc/timezone 2>/dev/null || echo UTC)" \
  -v /mnt/c/Users/LENOVO/Desktop/NoC/noc_power/gem5-23.0.0.1:/gem5 \
  -v /mnt/c/Users/LENOVO/Desktop/NoC/parsec-benchmark:/parsec-benchmark \
  -v /mnt/d/gem5_output_fluidanimate:/output \
  -v /etc/localtime:/etc/localtime:ro \
  -w /gem5 \
  -e LANG=C.UTF-8 \
  -e LC_ALL=C.UTF-8 \
  -it ghcr.io/gem5/ubuntu-22.04_all-dependencies:v23-0

**// Build Gem5**
scons build/X86_MESI_TWO_LEVEL/gem5.opt --default=X86 PROTOCOL=MESI_Two_Level -j$(nproc)

**// Run Gem5**
./build/X86_MESI_TWO_LEVEL/gem5.opt \
  -d /output \
  --debug-flags=NocPower \
  configs/deprecated/example/fskvm.py \
  --cpu-type=X86KvmCPU \
  --num-cpus=4 \
  --ruby \
  --network=garnet \
  --topology=Mesh_XY \
  --mesh-rows=2 \
  --num-dirs=4 \
  --num-l2caches=4 \
  --kernel=/parsec-benchmark/x86-linux-kernel-5.4.49 \
  --disk-image=/parsec-benchmark/parsec.img \
  --script=/gem5/run_fluidanimate.sh 2>&1 | tee /output/simulation.log

./build/X86_MESI_TWO_LEVEL/gem5.opt \
  -d /output \
  --debug-flags=RubyNetwork \
  configs/deprecated/example/fskvm.py \
  --cpu-type=X86KvmCPU \
  --num-cpus=4 \
  --ruby \
  --network=garnet \
  --topology=Mesh_XY \
  --mesh-rows=2 \
  --link-width-bits=64 \
  --num-dirs=4 \
  --num-l2caches=4 \
  --kernel=/parsec-benchmark/x86-linux-kernel-5.4.49 \
  --disk-image=/parsec-benchmark/parsec.img \
  --script=/gem5/run_fluidanimate.sh 2>&1 | tee /output/simulation.log
  
  ./build/X86_MESI_TWO_LEVEL/gem5.opt \
  -d /output \
  --debug-flags=OOO \
  configs/deprecated/example/fskvm.py \
  --cpu-type=X86KvmCPU \
  --num-cpus=4 \
  --ruby \
  --network=garnet \
  --topology=Mesh_XY \
  --mesh-rows=2 \
  --link-width-bits=64 \
  --num-dirs=4 \
  --num-l2caches=4 \
  --kernel=/parsec-benchmark/x86-linux-kernel-5.4.49 \
  --disk-image=/parsec-benchmark/parsec.img \
  --script=/gem5/run_fluidanimate.sh 2>&1 | tee /output/simulation.log

// without debug flag
./build/X86_MESI_TWO_LEVEL/gem5.opt \
  -d /output \
  configs/deprecated/example/fskvm.py \
  --cpu-type=X86KvmCPU \
  --num-cpus=4 \
  --ruby \
  --network=garnet \
  --topology=Mesh_XY \
  --mesh-rows=2 \
  --link-width-bits=64 \
  --num-dirs=4 \
  --num-l2caches=4 \
  --kernel=/parsec-benchmark/x86-linux-kernel-5.4.49 \
  --disk-image=/parsec-benchmark/parsec.img \
  --script=/gem5/helloworld.sh 2>&1 | tee /output/simulation.log

**//  Telemetry**
# In a new terminal on your host/WSL:
docker exec -it $(docker ps -lq) /bin/bash
cd /gem5/util/term
make
./m5term 3456


  ./build/X86_MESI_TWO_LEVEL/gem5.opt \
  -d /output \
  --debug-flags=OOO \
  configs/deprecated/example/fskvm.py \
  --cpu-type=X86KvmCPU \
  --num-cpus=4 \
  --ruby \
  --network=garnet \
  --topology=Mesh_XY \
  --mesh-rows=2 \
  --link-width-bits=64 \
  --num-dirs=4 \
  --vcs-per-vnet=1 \
  --num-l2caches=4 \
  --kernel=/parsec-benchmark/x86-linux-kernel-5.4.49 \
  --disk-image=/parsec-benchmark/parsec.img \
  --script=/gem5/run_fluidanimate.sh 2>&1 | tee /output/simulation.log