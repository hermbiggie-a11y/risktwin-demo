# RiskTwin: a local AI safety co-pilot for critical construction lifts

RiskTwin is a local multimodal safety sentinel for one critical crane lift, **LIFT-042**. It reads a site walkthrough,
a crew radio clip, recorded equipment and weather telemetry, a worker-zone event and the approved lift-plan rules, and
recommends `CONDITIONAL APPROVAL`, `HOLD` or `ESCALATE` with the evidence behind it, all on a Dell Pro Precision GB10.
It is **decision support**: a named human approves every lift clearance, and it never commands a crane, identifies
people by face, tracks a worker outside an active safety case or sends site data or model requests off the host.

## Watch it first

The overview video is under [Releases](../../releases).

## The stages

The demo question is: **can we safely start or restart Lift 042?** After the staged anomalies the expected answer is
`HOLD` or `ESCALATE`.

| # | What happens | Check or human gate |
| --- | --- | --- |
| 1 | The case opens with no lift plan in the store. | The Safety Commander cannot authorise anything: decision `ESCALATE` ("no applicable rule"). |
| 2 | **Import documents**: the lift plan and safety SOP are split into rule-bearing chunks; the Rules Retrieval agent cites **max gust 42 km/h** and **max load 85%**. | With those limits in the store and in-limit telemetry, the decision becomes `CONDITIONAL APPROVAL`. Every rule carries its document and page. |
| 3 | **Run media review**: sampled frames from the site walkthrough and the crew radio clip (or its transcript) become stored evidence. | Missing video or audio is recorded as unavailable and the case **escalates**; nothing is fabricated. |
| 4 | **Start replay**: the recorded / simulated LIFT-042 trace plays wind, load, worker and gateway events. | Deterministic checks, not the model: gust 46 km/h → `HOLD` (`46 − 42 = 4`, citation `lift-plan-042:p3`); floor gateway stale past its SLA → `ESCALATE`. |
| 5 | A phone on the private LAN opens `/worker` and reports **Zone C**. | Worker in Zone C during an active lift → `HOLD` and a targeted **STOP / ACK REQUIRED** alert; the acknowledgement is stored. |
| 6 | Optional **COLMAP 3D**: build a sparse 3D reconstruction from the walkthrough video. | Shown for orientation only; not survey-grade geometry. |
| 7 | **Issue lift clearance**, **Command the crane** or **request raw clip**. | OpenShell denies crane control and raw-media export, and holds the lift clearance for a **named human approver**. |
| 8 | Restart the API process. | The case and its decision come back from the store (`recovered from store` on the banner). |

The text model, when served, only writes the narrative. Thresholds, zones and freshness are plain code.

## Hardware

**Built and run on**

| Component | Built and run on |
| --- | --- |
| System | Dell Pro Precision GB10 |
| GPU | NVIDIA GB10 Grace Blackwell superchip, 128 GB unified LPDDR5x memory (shared by CPU and GPU) |
| CPU | 20-core NVIDIA Grace Arm CPU |
| Memory | 128 GB unified LPDDR5x memory (shared by CPU and GPU) |
| Storage | 4 TB NVMe SSD |
| OS | NVIDIA DGX OS |
| Software | Python 3.11+, Node 20+, MongoDB replica set with Change Streams, OpenClaw, NemoClaw, OpenShell (current versions, installed per NVIDIA's GB10 instructions; native via `.env.dgx.example`), local OpenAI-compatible inference servers, llama.cpp `llama-server` (installed separately, for GGUF fallbacks), COLMAP (optional, for 3D reconstruction) |

## What's in this repo

| Path | What |
| --- | --- |
| `apps/api/` | FastAPI ingest, case API and change-feed worker |
| `apps/dashboard/` | Controller dashboard and the `/worker` phone page (Next.js) |
| `agents/` | Orchestrator, six specialist agents and the policy gate |
| `packages/` | Contracts, store, site model, inference adapters, risk engine, media, replay, COLMAP reconstruction |
| `scripts/` | Bootstrap, ingest, data watcher, replay, local-inference smoke test, GB10 bring-up (`dgx_bringup.sh`, `dgx_setup.py`) |
| `config/` | OpenShell policy (`openshell-policy.yaml`) and the approved source registry (`sources.yaml`) |
| `data/raw/documents/` | Lift plan LIFT-042 and the crane safety SOP (team-authored) |
| `data/raw/video/`, `data/raw/audio/` | Where you drop the site walkthrough and crew radio clip (not included) |
| `data/recordings/lift-042-trace.json` | The recorded / simulated telemetry trace |
| `data/site-models/site-042-v1.json` | The 2.5D site model (floors F12/F13, zones A–D) |
| `data/ATTRIBUTION.md` | Origin and licence of every data asset and configured model |
| `tests/` | Pytest suite |
| `docs/DGX_DEPLOY.md` | Bring-up on the Dell Pro Precision GB10 |
| `docs/RUNBOOK.md` | Run, reset and fallback checklist |
| `.env.dgx.example`, `.env.mac.example` | GB10 runtime profile and the optional dry-run profile |
| `docker-compose.yml` | Local MongoDB replica set |
| `LICENSE`, `THIRD_PARTY_NOTICES.md` | Licence and third-party notices |

### The stack

| Framework | Role | Dry-run profile | GB10 profile |
| --- | --- | --- | --- |
| **OpenClaw** | Hosts the named specialist agent roles that write structured evidence back to the case store. | in-process runtime with the same contracts, concurrency limit and run journal | `RISKTWIN_AGENT_RUNTIME=openclaw` |
| **NemoClaw** | Manages sandbox lifecycle and local inference routing on the GB10. | local process lifecycle; durable state is in the store | `RISKTWIN_LIFECYCLE=nemoclaw` |
| **OpenShell** | Confines the agent sandbox: denies public egress, raw-media export and equipment actuation; requires a named human before a lift clearance. | auditable shim against `config/openshell-policy.yaml` | `RISKTWIN_OPENSHELL_BACKEND=native` |
| **MongoDB** | Durable evidence and event store, retrieval source and recovery layer; its change feed drives the agent loop. | file journal with the same change-feed semantics | Community Server replica set + Change Streams |

The dashboard **Stack, models and replay** panel reports `native` or `shim` for each.

### Models

Configured names live in `.env.dgx.example`. Nothing is downloaded by this repository.

| Modality | GB10 model | Dry-run adapter |
| --- | --- | --- |
| Text (shared agent model) | NVIDIA Nemotron 3.5 Lightning 30B A3B NVFP4 at `127.0.0.1:8001` | deterministic risk engine + template narrative (`degraded model mode`) |
| Vision | NVIDIA Nemotron Nano 12B v2 VL NVFP4-QAD on **sampled frames** at `127.0.0.1:8002` | OpenCV median-diff + HOG people detector; findings labelled as candidates |
| Speech | NVIDIA Parakeet Unified English 0.6B at `127.0.0.1:8003` | operator transcript sidecar only; missing audio is reported unavailable |

Fallback ladder on the GB10, in order: Lightning 30B → Super 120B (only if already loaded) → Llama 3.1 Nemotron 70B
GGUF → Nano 4B (labelled degraded). Vision fallbacks: Nano VL 8B → Qwen2.5-VL-7B → deterministic CV. Speech fallback:
Parakeet TDT 0.6B v3.

## Setup

Linux on the Dell Pro Precision GB10 (NVIDIA DGX OS).

1. Put this repository on the GB10 (download or clone it) and open a terminal in its folder.
2. Create the Python environment:
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -e ".[dev]"
   ```
3. Select the GB10 profile: `cp .env.dgx.example .env`
4. Start MongoDB as a local replica set and prepare it:
   ```bash
   docker compose up -d
   python scripts/bootstrap_mongo.py
   ```
5. Start the local model servers on loopback (ports 8001, 8002, 8003) as described in
   [docs/DGX_DEPLOY.md](docs/DGX_DEPLOY.md). `scripts/dgx_bringup.sh` can start MongoDB, the model servers, the API and
   the dashboard in one go.
6. Install the current versions of OpenClaw, NemoClaw and OpenShell per NVIDIA's GB10 instructions, as described in
   [docs/DGX_DEPLOY.md](docs/DGX_DEPLOY.md).
7. Prove the inference path is local (must pass before anything else):
   `python scripts/smoke_test_local_inference.py`
8. Import the cleared documents and trace: `python scripts/ingest_cleared_data.py`
9. Run the tests: `python -m pytest tests -q`
10. Start the API: `python -m uvicorn apps.api.main:app --host 0.0.0.0 --port 8000`
11. In a second terminal, start the dashboard:
    ```bash
    cd apps/dashboard
    npm install
    npm run build && npm start
    ```
    Controller dashboard: `http://127.0.0.1:3000` · Worker page: `http://127.0.0.1:3000/worker` · API:
    `http://127.0.0.1:8000/docs`. Phones on the same private LAN scan the dashboard QR or open
    `http://<host-lan-ip>:3000/worker`; MongoDB and the model ports stay on loopback.
12. Supply your own media (customer-supplied inputs, not included):

    | Path | What to put there |
    | --- | --- |
    | `data/raw/video/` | Site walkthrough: a 15–25 s `.mp4` you recorded or are licensed to use, optional `<clip>.mp4.meta.json` zone regions |
    | `data/raw/audio/` | Crew radio clip: an 8–15 s 16 kHz mono `.wav`. If no speech model is served, also `<clip>.wav.transcript.txt` |

    Then click **run media review** on the dashboard. With COLMAP installed, choose **COLMAP 3D → build 3D from video**;
    set `RISKTWIN_COLMAP_BINARY` when the executable is not on `PATH`.

**Optional dry run, no models:** `cp .env.mac.example .env` runs the full application, agent loop, replay, dashboard and
worker page with deterministic local adapters, a file journal instead of MongoDB, and shims for OpenClaw, NemoClaw and
OpenShell. The dashboard labels it `degraded model mode` and `shim`.

The full run, reset and fallback checklist is in [docs/RUNBOOK.md](docs/RUNBOOK.md); the GB10 bring-up is in
[docs/DGX_DEPLOY.md](docs/DGX_DEPLOY.md).

## Known limits

- **Decision support only.** A named human approves every lift clearance; RiskTwin never commands a crane.
- **Not survey-grade.** The 2.5D zone map and the COLMAP sparse reconstruction are for orientation, not survey geometry.
- **Sampled frames plus transcript.** Video analysis uses sampled still frames and the crew audio is used as a
  transcript; the text model never "watches" video.
- **Missing media escalates.** Without a walkthrough or radio clip, Vision Risk and Crew Comms record the evidence as
  unavailable and the case escalates; nothing is fabricated.
- **Simulated data.** Worker location data is simulated (zone events from the worker page), and the telemetry is a
  recorded / simulated trace: no physical sensor was present.
- **Framework mode is reported, not assumed.** If OpenClaw, NemoClaw or OpenShell is not installed, the code falls
  back to a shim and the dashboard shows `shim`; if a model server is down, it shows `degraded model mode`.
- **llama.cpp is not bundled.** `scripts/dgx_bringup.sh` uses an installed `llama-server` for its GGUF fallbacks; it
  no longer downloads llama.cpp itself.

## Credits

Created by the RiskTwin team: Tanmay Sahu and Subhradeep Acharjee. Original repository:
[7dracoder/RiskTwin](https://github.com/7dracoder/RiskTwin). If this demo is useful to you, please star the team's repository.
A fork of it is at [Subhradeep246/RiskTwin](https://github.com/Subhradeep246/RiskTwin).

- **Partners:** NVIDIA (GB10 Grace Blackwell superchip, Nemotron and Parakeet models, NemoClaw, OpenShell) and
  MongoDB (MongoDB Community Server, Change Streams). OpenClaw hosts the agent roles.
- **Upstream licences:** the original repository has no licence file; Dell publishes this copy with the team's
  permission (see `LICENSE`). Third-party components keep their own licences, listed in `THIRD_PARTY_NOTICES.md` and
  `data/ATTRIBUTION.md`. No dependency repository is copied into this repo; OpenClaw, NemoClaw, OpenShell, MongoDB,
  COLMAP and the models are products you install.
- **Data:** the lift plan, safety SOP, site model and telemetry trace were written by the RiskTwin team for this demo
  and are not customer documents.
- **Changes by Dell Technologies:** Dell rewrote the README and setup docs, added the run, reset and fallback
  checklist, licence and notices, renamed the two configuration profiles to `.env.dgx.example` and
  `.env.mac.example`, and removed personal paths and the bring-up script's download of llama.cpp.

Dell and Dell Pro Precision are trademarks of Dell Inc. or its subsidiaries. NVIDIA, Grace, Blackwell, DGX, Nemotron and
Parakeet are trademarks of NVIDIA Corporation. MongoDB is a trademark of MongoDB, Inc. Llama is a trademark
of Meta Platforms, Inc. Qwen is a trademark of Alibaba Group. Next.js is a trademark of Vercel, Inc. Docker is a
trademark of Docker, Inc. Other names are trademarks of their respective owners. Their use here does not imply
endorsement of Dell or of this demo by their owners, or of their products by Dell.

## Support

Logan Lawler, Dell Technologies: [logan.lawler@dell.com](mailto:logan.lawler@dell.com)

## License

See [LICENSE](LICENSE). This is not an open-source licence: RiskTwin is Copyright (c) 2026 the RiskTwin team, all rights
reserved by the authors, and Dell shares it with their permission so that you can download, run and evaluate it as a
demo. Dell's changes are Copyright (c) 2026 Dell Inc. under the same terms. Third-party notices are in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
