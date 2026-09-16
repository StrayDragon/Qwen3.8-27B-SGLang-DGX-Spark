# templates/

Optional chat-template overrides for `start.sh`'s `CHAT_TEMPLATE` knob.
Unset (the default) means the server uses the checkpoint's own
`chat_template.jinja` — byte-identical to the official
[`Qwen/Qwen3.8-27B`](https://huggingface.co/Qwen/Qwen3.8-27B) template for
every shipped `QUANT` checkpoint (verified against
`RadixArk/Qwen3.8-27B-NVFP4-BF16-LMHead` and `Qwen/Qwen3.8-27B`).

## qwen3.8-froggeric-v22.jinja

- **Source**: [froggeric/Qwen-Fixed-Chat-Templates](https://huggingface.co/froggeric/Qwen-Fixed-Chat-Templates)
  (v22, template id `qwen3.8-froggeric-v22`), imported 2026-09-16 from the
  locally-archived 2026-08-16 vLLM deployment (`…-Qwen3.8-27B-FP8-最终最优/模板/`)
  where it was the validated production template.
- **Integrity**: `md5sum` = `23640fe04f460610cdb044f25cd80b71`, matching the
  md5 documented in that archive. Keep the file byte-identical on any update
  so the checksum stays comparable.
- **Why it exists**: the stock Qwen3.8 template `raise_exception`s on three
  reachable request shapes — a per-request HTTP 500, not a server crash:
  1. `reasoning_effort` outside `xhigh|medium|low` (e.g. the OpenAI-standard
     `high`/`minimal`). SGLang forwards `reasoning_effort` verbatim into the
     template (verified at the pinned image commit `708f51e44`,
     `serving_chat.py`), so any OpenAI-SDK client that sends it can trip this.
  2. system/developer messages after the first message.
  3. histories with no user message at all (agent handoff tails).
  v22 maps unknown efforts to xhigh and renders all three. Agent-loop
  hardening on top: consecutive tool-error detection injects a warning into
  `<tool_response>`, optional `max_tool_arg_chars` /
  `max_tool_response_chars` truncation (default off),
  `<|think_on|>`/`<|think_off|>` text markers, and
  `auto_disable_thinking_with_tools` — all default-off/inert.
- **Compatibility** (render-tested against the stock template in a
  transformers-style jinja2 sandbox): plain chat, `enable_thinking=false`,
  and `reasoning_content` history render byte-identical; the generation
  prompt shape (`<think>\n` thinking / `<think>\n\n</think>\n\n` not) is
  unchanged, so `--reasoning-parser qwen3` is unaffected; the default
  `tool_call_format='xml'` renders the exact `<tool_call><function=…>` /
  `<parameter=…>` shape `--tool-call-parser qwen3_coder` decodes.
  **Do not** send `chat_template_kwargs={"tool_call_format": "json"}` —
  that emits hermes-style JSON, which `qwen3_coder` never parses.
- **Status**: render matrix and start.sh wiring verified off-box
  (CHANGELOG 2026-09-16); not yet benchmarked on the GB10. **This is the
  fork default** — opt out (serve the checkpoint's own template) with
  `CHAT_TEMPLATE=stock`, or override with any other `.jinja`.
