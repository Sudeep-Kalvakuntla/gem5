#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

scons build/NULL/gem5.opt PROTOCOL=Garnet_standalone -j 12
