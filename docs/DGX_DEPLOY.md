# Runtime host (Dell Pro Precision GB10)

This is the profile that runs RiskTwin with MongoDB, the local models and native OpenClaw, NemoClaw and OpenShell.
The optional dry-run profile (`.env.mac.example`) needs none of them.

## 0. Copy the repository

Copy the repository onto the Dell (USB, `rsync` over the private LAN, etc.). Do not copy secrets. `.env` is
gitignored; use the committed profile:

```bash
cp .env.dgx.example .env
```

## 1. MongoDB Community, replica set

Change Streams need a replica set. Either:

```bash
docker compose up -d
python scripts/bootstrap_mongo.py
```

or a host `mongod`:

```bash
mongod --replSet rs0 --dbpath /data/risktwin --bind_ip 127.0.0.1 --port 27017
mongosh --eval 'rs.initiate({_id: "rs0", members: [{_id: 0, host: "127.0.0.1:27017"}]})'
python scripts/bootstrap_mongo.py
```

Confirm `GET /api/health` later reports `changeFeed: mongodb-change-stream` and a replica set name.

## 2. Local model servers (loopback only)

Bind every server to `127.0.0.1`. Suggested ports match `.env.dgx.example`:

| Port | Modality | First-choice model |
| --- | --- | --- |
| 8001 | text | NVIDIA Nemotron 3.5 Lightning 30B A3B NVFP4 |
| 8002 | vision | NVIDIA Nemotron Nano 12B v2 VL NVFP4-QAD |
| 8003 | speech | NVIDIA Parakeet Unified English 0.6B |

Bring-up order:

1. Smoke-test Parakeet on the radio clip.
2. Smoke-test Nano V2 VL 12B on four local frames; fall back to Nano VL 8B or Qwen if it does not start.
3. Write both outputs as evidence.
4. Start Lightning 30B and confirm it reasons over **stored evidence**, not raw files.

Limit concurrent text generations to one or two. One primary text model; agent specialisation is not extra weights.

If a server fails to start, set the matching backend in `.env` to `deterministic` and **say degraded model mode**. Do
not claim VLM or ASR quality you are not getting.

`scripts/dgx_bringup.sh` automates this step with vLLM, llama.cpp's `llama-server` and NVIDIA NeMo where they are
installed. It does not download any of them: install `llama-server` yourself (on `PATH`, in `/usr/local/bin`, or built
in `~/llama.cpp`) if you want its GGUF fallbacks.

## 3. Frameworks

Install the current versions of OpenShell, OpenClaw and NemoClaw per NVIDIA's instructions for the GB10 image you have.
Then:

```
RISKTWIN_OPENSHELL_BACKEND=native
RISKTWIN_AGENT_RUNTIME=openclaw
RISKTWIN_LIFECYCLE=nemoclaw
```

If a package is missing, the code falls back to the shim and the dashboard reports `mode: shim`. Fix the install
before relying on it; do not hide the gap.

## 4. Bring-up

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
python scripts/smoke_test_local_inference.py   # must PASS with public egress denied
python scripts/bootstrap_mongo.py
python scripts/ingest_cleared_data.py
python -m pytest tests -q                     # sanity check after the copy
python -m uvicorn apps.api.main:app --host 0.0.0.0 --port 8000
```

Dashboard:

```bash
cd apps/dashboard && npm install && npm run build && npm start
```

`RISKTWIN_API_HOST=0.0.0.0` serves the Worker API on the private LAN. MongoDB and model ports stay on `127.0.0.1`.

## 5. Private LAN

Put the Dell, the controller laptop or tablet, and the worker phones on the **same private LAN**. If the Wi-Fi isolates
clients, use your own private router.

Worker URL: `http://<GB10-LAN-IP>:3000/worker`

No model endpoint and no MongoDB port on that URL. Wi-Fi is transport only.

## 6. Local-first gate before you run

- `python scripts/smoke_test_local_inference.py` → PASS
- Disconnect or deny public egress
- Dashboard shows `degraded model mode` only if a modality really is deterministic
- Recovery: restart uvicorn; banner shows recovered from store

## 7. Record what actually ran

After the smoke test on the Dell, write down:

- Exact model ids and revisions that answered
- OpenClaw / NemoClaw / OpenShell versions
- MongoDB version and replica set name
- Checksums from `scripts/ingest_cleared_data.py --report …`

Those lines describe what really ran, not the configured-but-unused fallbacks.

The run, reset and fallback checklist is in [RUNBOOK.md](RUNBOOK.md).
