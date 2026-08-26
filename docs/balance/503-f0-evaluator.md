# #503 F0 evaluator — Tier-2 paired controls and mini-landscapes

See [`2026-08-26-503-tier2-f0.md`](2026-08-26-503-tier2-f0.md) for the screen.
Protocol: [`503-f0-protocol-v1.json`](503-f0-protocol-v1.json).
Response contract (frozen by #508): [`508-f0-response-contract-v1.json`](508-f0-response-contract-v1.json).

```bash
export PATH=/tmp/glassvow-503-godot.EEEdaL/bin:$PATH
export HOME=/tmp/g471-home
python3 -B tools/balance_tier2_design.py --out DIR/doe --force
python3 -B tools/balance_f0.py \
  --protocol docs/balance/503-f0-protocol-v1.json --evaluation f0 \
  --jobs 8 --boot 10000 --out DIR --candidates DIR/doe
```
