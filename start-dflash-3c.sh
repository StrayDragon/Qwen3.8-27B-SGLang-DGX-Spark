#!/usr/bin/env bash
set -euo pipefail

# start-dflash-3c.sh — DFLASH serving, capped at 3 concurrent requests.
#
# Thin wrapper around start-dflash.sh. We do NOT copy the launch config:
# start-dflash.sh (which delegates to start.sh) is the single source of
# truth for the DFLASH flag stack. This script only layers a concurrency-
# specific KV/concurrency override on top via DF_EXTRA.
#
# Why DF_EXTRA and not a file edit: start-dflash.sh appends ${DF_EXTRA}
# LAST on its EXTRA_ARGS string, so argparse's last-wins rule lets these
# override anything baked in (mem-fraction-static, model-path, etc.).
#
# The three knobs:
#   --max-total-tokens 1000000   cap the main KV pool at 1M tokens (~33 GB).
#                                This is the "KV usage <= 1M" ceiling from
#                                the fork plan; without it the pool would
#                                otherwise fill the 0.90 reserved fraction.
#   --max-mamba-cache-size 15    15 / 5 state-slots-per-request = 3 running.
#                                NOTE: the stock MAX_CONCURRENT_REQUESTS=3
#                                computes a 12-slot pool, and floor(12/5)=2,
#                                so concurrency silently collapses to 2.
#                                15 is the explicit fix.
#   --max-running-requests 3     scheduler cap matches.
#
# mem-fraction-static is intentionally left at start-dflash.sh's 0.90
# (the stable value for DFLASH on GB10; 0.95 hard-reboots the box). KV is
# now capped by max-total-tokens, so lowering the fraction buys nothing
# here and risks CUDA-graph capture headroom.
#
# Override any single value without editing this file:
#   DF_EXTRA="--max-total-tokens 500000 --max-mamba-cache-size 15 \
#             --max-running-requests 3" ./start-dflash.sh
# (the shell's DF_EXTRA wins — see the ${DF_EXTRA:-} default below.)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default to the 3-concurrency stack, but let a pre-set DF_EXTRA in the
# environment win (so ad-hoc overrides still work).
DF_EXTRA="${DF_EXTRA:-\
--max-total-tokens 1000000 \
--max-mamba-cache-size 15 \
--max-running-requests 3}"
export DF_EXTRA

echo "[start-dflash-3c] 3-concurrency DFLASH stack: ${DF_EXTRA}"
exec "${SCRIPT_DIR}/start-dflash.sh"
