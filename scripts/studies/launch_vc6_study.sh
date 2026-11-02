#!/bin/bash
# ==============================================================================
# Script: launch_vc6_study.sh (Alias for launch_vc6_small_study.sh)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/launch_vc6_small_study.sh" "$@"
