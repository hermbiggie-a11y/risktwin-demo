# RiskTwin run, reset and fallback checklist

The dashboard shows **RECORDED / SIMULATED SITE TELEMETRY — REPLAY MODE** the whole time. RiskTwin is decision
support: a qualified human approves every lift.

## Before you run

- [ ] `.env` is the GB10 profile (`cp .env.dgx.example .env`), or the dry-run profile (`cp .env.mac.example .env`).
- [ ] MongoDB replica set is up and `python scripts/bootstrap_mongo.py` passed; `GET /api/health` reports
      `changeFeed: mongodb-change-stream` and a replica set name (GB10 profile).
- [ ] `python scripts/smoke_test_local_inference.py` → PASS. It fails if any configured endpoint is not local, or if a
      source file mentions a hosted LLM, ASR, vision or weather hostname.
- [ ] Public egress is disconnected or denied.
- [ ] `python scripts/ingest_cleared_data.py` imported the documents and the trace.
- [ ] `python -m pytest tests -q` passes.
- [ ] API (port 8000) and dashboard (port 3000) are running; the worker phone is on the same private LAN.
- [ ] The **Stack, models and replay** panel shows `native` or `shim` for each framework, and `degraded model mode`
      only if a modality really is deterministic.
- [ ] Optional: the site walkthrough `.mp4` is in `data/raw/video/` and the crew radio `.wav` (or its transcript) is in
      `data/raw/audio/`.

## Run (dashboard controls)

1. **Import documents**: retrieval changes the case from `ESCALATE` (no applicable rule) to `CONDITIONAL APPROVAL`
   when telemetry is in limit.
2. **Run media review** (if media is present): Zone C on the 2.5D plan turns red from local sampled-frame evidence.
3. **Start replay**: the recorded LIFT-042 trace (wind, load, worker, gateway stale).
4. On a phone, scan the worker QR, open `/worker` and pick **Zone C**. The phone gets **STOP / ACK REQUIRED**; tap
   acknowledge and the controller timeline records it.
5. Open the forensic timeline → policy evidence: **42 km/h** and **85%** are cited from the lift plan. The gust to
   46 km/h flips the decision to `HOLD` with `46 − 42 = 4` and citation `lift-plan-042:p3`; the stale gateway gives
   `ESCALATE`.
6. Open **COLMAP 3D** to inspect or rebuild the walkthrough reconstruction (COLMAP installed).
7. **Issue lift clearance** → `BLOCKED` / `AWAITING_APPROVAL`. **Command the crane** → denied. **Request raw clip** →
   denied. The policy log shows the same verdict.
8. Restart the API process. The banner shows **recovered from store** and `LIFT-042` keeps its decision and evidence
   ids.

## Reset

- `python scripts/replay_scenario.py --reset` drives the whole LIFT-042 sequence again in-process from the start.

## Fallbacks

| If this is broken | Do this |
| --- | --- |
| No walkthrough clip | Skip the red overlay; keep retrieval, worker zone and policy. The case escalates for missing visual evidence, by design. |
| Dashboard lag | Follow the sequence from `python scripts/replay_scenario.py --reset` in a terminal. |
| Phone not on the LAN | Drive the worker event from the dashboard host's browser at `/worker`. |
| Model server down | Set the matching backend in `.env` to `deterministic` and leave **degraded model mode** visible; do not present it as a model having watched the video. |
| Framework missing | The code falls back to the shim and the dashboard reports `mode: shim`; fix the install as in `docs/DGX_DEPLOY.md`. |
