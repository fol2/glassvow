# #491 F0 evaluator — Tier-1 paired controls and mini-landscapes

See [`2026-08-26-491-tier1-f0.md`](2026-08-26-491-tier1-f0.md) for the screen.
Protocol: [`491-f0-protocol-v1.json`](491-f0-protocol-v1.json).
Response contract (frozen by #490): [`490-f0-response-contract-v1.json`](490-f0-response-contract-v1.json).

```bash
python3 -B tools/balance_tier1_design.py --out DIR/doe --force
python3 -B tools/balance_f0.py \
  --protocol docs/balance/491-f0-protocol-v1.json --evaluation f0 \
  --jobs 8 --boot 1000 --out DIR --candidates DIR/doe
```
