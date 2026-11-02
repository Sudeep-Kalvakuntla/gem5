#!/bin/bash
# ==============================================================================
# Script: run_oip_vc6_study.sh (Alias for run_oip_vc6_small_study.sh)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/run_oip_vc6_small_study.sh" "$@"
