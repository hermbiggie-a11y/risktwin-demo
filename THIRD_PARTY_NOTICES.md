# Third-party notices

## RiskTwin (original project)

Created by the RiskTwin team: Tanmay Sahu and Subhradeep Acharjee. Source:
[7dracoder/RiskTwin](https://github.com/7dracoder/RiskTwin). The repository has no licence file and no notice file,
so there is no upstream notice text to reproduce. Dell publishes this copy with the team's permission; see `LICENSE`.

No third-party repository is copied into this repo, and no third-party source file is bundled.

## Components you install

These are installed by you (pip, npm, Docker or the vendor's own installer) and are not shipped in this repository.
Each keeps its own licence, which is installed with it. The licences shown are those recorded in
`data/ATTRIBUTION.md`.

| Component | Used for | Licence |
| --- | --- | --- |
| FastAPI, Pydantic, Uvicorn | API | MIT |
| pymongo | MongoDB driver | Apache-2.0 |
| OpenCV (`opencv-python-headless` 4.x) | frame sampling, CV observations, redaction | Apache-2.0 |
| Next.js, React | dashboard | MIT |
| MongoDB Community Server (`mongo:7` image) | runtime store | SSPL (server only; not shipped in this repo) |
| pydantic-settings, httpx, PyYAML, python-multipart, NumPy, pypdf, pytest, pytest-asyncio, Ruff | Python dependencies in `pyproject.toml` | see each package's own licence |
| Dashboard npm packages | listed in `apps/dashboard/package.json` and `package-lock.json` | see each package's own licence |
| OpenClaw, NemoClaw, OpenShell | agent runtime, sandbox lifecycle, policy enforcement | see each product's own licence |
| COLMAP (optional) | sparse 3D reconstruction | see the COLMAP project's licence |
| llama.cpp `llama-server`, vLLM, NVIDIA NeMo (optional, used by `scripts/dgx_bringup.sh`) | local model serving | see each project's own licence |

## Models

No model weights are in this repository. The models the GB10 profile is configured for, and their licence or model
card, are listed in `data/ATTRIBUTION.md` (NVIDIA Nemotron and Parakeet models, a Llama 3.1 Nemotron community GGUF and
Qwen2.5-VL-7B-Instruct). Each model is used under its own licence and model card.
