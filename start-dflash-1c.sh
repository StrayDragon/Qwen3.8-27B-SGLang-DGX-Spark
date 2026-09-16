#!/usr/bin/env bash
set -euo pipefail

# start-dflash-1c.sh — DFLASH serving, single-stream (1 concurrent request).
#
# Thin wrapper around start-dflash.sh (which delegates to start.sh). Same
# rationale as start-dflash-3c.sh: we layer a concurrency/KV override on
# top via DF_EXTRA (appended last -> last-wins) instead of copying config.
#
# The single-stream philosophy: the KV pool only ever serves ONE sequence,
# so size it to your longest single request instead of filling memory.
#
# The knobs:
#   --max-total-tokens 262144    main KV pool = exactly one native 262K
#                                sequence (~8.7 GB) — the most frugal
#                                setting. Raise to 1000000 if you need a
#                                single request to run up to 1M context
#                                (~33 GB); in single-stream mode that is
#                                never oversubscribed, just headroom.
#   --max-mamba-cache-size 5     5 / 5 state-slots-per-request = 1 running.
#                                5 is the per-request minimum (see the
#                                engine log: "5 state slots per request").
#   --max-running-requests 1     scheduler cap = 1.
#   --chunked-prefill-size 2048  (optional single-stream latency tweak)
#                                default is 8192; 2048 gives smoother
#                                inter-token latency / better single-wave
#                                TTFT at some prefill-throughput cost.
#                                Drop it (or set 8192) if you prefer max
#                                prefill throughput.
#
# mem-fraction-static stays at start-dflash.sh's 0.90 (GB10 DFLASH-stable).
# The DFLASH fused KV also shrinks automatically with max_running=1.
#
# Override any single value without editing this file:
#   DF_EXTRA="--max-total-tokens 524288 --max-mamba-cache-size 5 \
#             --max-running-requests 1" ./start-dflash.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default to the frugal single-stream stack; a pre-set DF_EXTRA in the
# environment wins (so ad-hoc overrides still work).
DF_EXTRA="${DF_EXTRA:-\
--max-total-tokens 262144 \
--max-mamba-cache-size 5 \
--max-running-requests 1 \
--chunked-prefill-size 2048}"
export DF_EXTRA

echo "[start-dflash-1c] single-stream DFLASH stack: ${DF_EXTRA}"
exec "${SCRIPT_DIR}/start-dflash.sh"
