# Lab-on-chip Monitor

> A full-stack simulation of a **Lab-on-Chip medical device** for personalised cancer treatment. A C++ backend simulates hardware sensors and runs computer-vision-based drug efficacy analysis. A Flutter desktop frontend provides a real-time clinical dashboard for lab technicians.

---

## Table of Contents

- [What is this?](#what-is-this)
- [Architecture Overview](#architecture-overview)
- [Data Flow Diagram](#data-flow-diagram)
- [Backend Services](#backend-services)
  - [Sensor Server (Port 8080)](#sensor-server-port-8080)
  - [Cell Analyzer (Port 8081)](#cell-analyzer-port-8081)
  - [API Reference](#api-reference)
- [Frontend (Flutter)](#frontend-flutter)
- [Docker Setup](#docker-setup)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Run with Docker (recommended)](#run-with-docker-recommended)
  - [Run manually](#run-manually)
- [Project Structure](#project-structure)

---

## What is this?

This project simulates the software stack of a **TheraMeDx1 Sampler™** — a microfluidic lab-on-chip device used in oncology research. The device takes a biopsy sample, encapsulates individual cells in nano-droplets, exposes them to a library of 20 chemotherapy drugs, and uses fluorescence microscopy to identify which drug is most effective for that specific patient's tumour.

The simulator replaces the physical hardware with two C++ servers running in Docker containers. The Flutter app runs natively on macOS/Windows/Linux and communicates with both servers over HTTP.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     macOS / Windows / Linux                     │
│                                                                 │
│   ┌──────────────────────────────────────────────────────────┐  │
│   │               Flutter Desktop App  (Dart)                │  │
│   │                                                          │  │
│   │  ┌────────────┐  ┌──────────────┐  ┌─────────────────┐  │  │
│   │  │ Environment│  │   Protocol   │  │    Oncology     │  │  │
│   │  │   Panel    │  │   Run Panel  │  │     Panel       │  │  │
│   │  │            │  │              │  │                 │  │  │
│   │  │ Polls every│  │ 8-step state │  │ Unlocks after   │  │  │
│   │  │ 1s via GET │  │ machine with │  │ imaging step    │  │  │
│   │  │            │  │ timer ticks  │  │ triggers GET    │  │  │
│   └──┴──────┬─────┴──┴──────────────┴──┴────────┬────────┴──┘  │
│             │  HTTP/JSON                          │  HTTP/JSON   │
│             │  localhost:8080                     │  localhost:8081
└─────────────┼─────────────────────────────────────┼─────────────┘
              │                                     │
     ┌────────▼────────┐                 ┌──────────▼──────────┐
     │   Docker        │                 │   Docker            │
     │   Container 1   │                 │   Container 2       │
     │                 │                 │                     │
     │  sensor_server  │                 │  cell_analyzer      │
     │  (C++/httplib)  │                 │  (C++/httplib       │
     │                 │                 │   + OpenCV)         │
     │  Port 8080      │                 │  Port 8081          │
     │                 │                 │                     │
     │  • 6 simulated  │                 │  • Generates        │
     │    sensors      │                 │    synthetic cell   │
     │  • Noise model  │                 │    microscopy       │
     │  • CSV logger   │                 │    images           │
     │  • Alarm levels │                 │  • Blob detection   │
     │  • Target ctrl  │                 │  • 20 drug wells    │
     └─────────────────┘                 │  • Efficacy ranking │
                                         └─────────────────────┘
```

---

## Data Flow Diagram

```
ENVIRONMENT MONITORING (every 1 second)
────────────────────────────────────────
Flutter                     sensor_server (C++)
  │                               │
  │── GET /api/environment ──────►│
  │                               │  Each sensor applies:
  │                               │  value += (target - value) * 0.05
  │                               │           + gaussian_noise
  │◄── JSON {temp, humidity, ─────│
  │    co2, o2, pressure, ph,     │
  │    alarm_levels} ─────────────│
  │                               │
  │  [User adjusts target]        │
  │── POST /api/targets ─────────►│  Updates setTarget() on each
  │   {temperature: 38.0, ...}    │  Sensor object → simulation
  │◄── {status: "ok"} ────────────│  drifts toward new value


PROTOCOL RUN (timer-driven, fully in Flutter)
──────────────────────────────────────────────
  Flutter state machine runs 8 steps:
  Intake → Dissociation → Droplets → Drug Loading
  → Incubation → Imaging → Analysis → Report

  On session start:
  │── POST /api/logger/start {patient_id} ──►  sensor_server
  │                                            spawns logger_thread()
  │                                            writes CSV every 1s to
  │                                            ./logs/env_log_<id>_<ts>.csv

  On session end / patient switch:
  │── POST /api/logger/stop ────────────────►  sensor_server
                                               flushes & closes CSV


ONCOLOGY ANALYSIS (on demand, after imaging step)
──────────────────────────────────────────────────
Flutter                     cell_analyzer (C++)
  │                               │
  │── GET /api/analyze ──────────►│
  │                               │  For each of 20 drugs:
  │                               │  1. generate_well_frame()
  │                               │     → synthetic grayscale image
  │                               │     → gaussian cells (bright=alive)
  │                               │  2. detect_blobs() via OpenCV
  │                               │     SimpleBlobDetector
  │                               │  3. classify_blob() → alive/dead
  │                               │     (mean pixel intensity > 75)
  │                               │  4. annotate_well() → PNG with
  │                               │     green/red circles + label
  │                               │  5. base64-encode PNG
  │                               │  6. rank by efficacy (100 - viability)
  │                               │
  │◄── JSON {best_drug,           │
  │    best_efficacy, ranked[5],  │
  │    wells[20] with frame_b64} ─│
  │                               │
  Flutter renders:
  • Heatmap grid of 20 wells
  • Microscopy image viewer
  • Top-5 ranked drug sidebar
  • Treatment recommendation banner
```

---

## Backend Services

### Sensor Server (Port 8080)

**File:** `backend/sensor_server.cpp`  
**Language:** C++17 with [cpp-httplib](https://github.com/yhirose/cpp-httplib)

Simulates 6 incubation chamber sensors using a **mean-reversion + Gaussian noise** model. Each sensor has a `value`, a `target`, and a `noise_scale`. Every time the sensor is read, it drifts slightly toward the target and adds random noise — mimicking real hardware drift.

| Sensor | Default Target | Unit | Alarm thresholds |
|---|---|---|---|
| Temperature | 37.0 | °C | warn: 36.5–37.5 · crit: 35–39 |
| Humidity | 95.0 | %RH | warn: 90–98 · crit: 80–99.9 |
| CO₂ | 5.0 | % | warn: 4.5–5.5 · crit: 3–7 |
| O₂ | 21.0 | % | warn: 19–22 · crit: 15–24 |
| Pressure | 1013.0 | mbar | warn: 1005–1020 · crit: 950–1050 |
| pH | 7.4 | pH | warn: 7.2–7.6 · crit: 6.8–7.8 |

**CSV Logger:** When a session starts, a background thread writes one row per second to `./logs/env_log_<patient_id>_<timestamp>.csv`. Files roll over at 3600 rows (1 hour). A maximum of 10 log files are kept.

---

### Cell Analyzer (Port 8081)

**File:** `backend/cell_analyzer.cpp`  
**Language:** C++17 with [cpp-httplib](https://github.com/yhirose/cpp-httplib) + [OpenCV 4](https://opencv.org/)

Simulates a fluorescence microscopy imaging pipeline. When called, it processes 20 virtual drug wells:

1. **`generate_well_frame()`** — Creates a 320×320 grayscale image. Bright Gaussian blobs = live cells, dim blobs = dead cells. The ratio is controlled by each drug's known `survival_rate`.
2. **`detect_blobs()`** — Runs OpenCV's `SimpleBlobDetector` to find cell-like objects.
3. **`classify_blob()`** — Classifies each blob as alive (mean intensity > 75) or dead.
4. **`annotate_well()`** — Draws green circles (alive) and red circles (dead) on a BGR image, adds drug name and efficacy %.
5. The PNG is base64-encoded inline into the JSON response.
6. Wells are ranked by **efficacy = 100 − viability %**.

**Drugs simulated (20 wells):**

| Drug | Category | Survival Rate |
|---|---|---|
| Paclitaxel | Taxane | 18% |
| Doxorubicin | Anthracycline | 22% |
| Docetaxel | Taxane | 20% |
| Imatinib | Tyrosine kinase inh. | 28% |
| Cisplatin | Platinum agent | 30% |
| Erlotinib | EGFR inhibitor | 32% |
| Oxaliplatin | Platinum agent | 33% |
| Carboplatin | Platinum agent | 35% |
| … | … | … |
| Control (None) | Negative control | 92% |

---

### API Reference

#### Sensor Server — `localhost:8080`

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/environment` | Returns all 6 sensor readings with values, units, targets, alarm levels |
| `GET` | `/api/temperature` | Single temperature reading |
| `GET` | `/api/status` | Server health + logging state |
| `GET` | `/api/logs` | List of CSV log files |
| `POST` | `/api/logger/start` | Start CSV logging `{"patient_id": "PAT-2024-001"}` |
| `POST` | `/api/logger/stop` | Stop CSV logging, returns filename |
| `POST` | `/api/targets` | Update sensor targets `{"temperature": 38.0, "humidity": 90.0, ...}` |

**Example response — `/api/environment`:**
```json
{
  "temperature": {"value": 36.98, "unit": "C",   "target": 37.0, "alarm": "ok"},
  "humidity":    {"value": 94.72, "unit": "%RH",  "target": 95.0, "alarm": "ok"},
  "co2":         {"value":  5.02, "unit": "%",    "target":  5.0, "alarm": "ok"},
  "o2":          {"value": 20.95, "unit": "%",    "target": 21.0, "alarm": "ok"},
  "pressure":    {"value": 1012.6,"unit": "mbar", "target": 1013.0,"alarm":"ok"},
  "ph":          {"value":  7.401,"unit": "pH",   "target":  7.4, "alarm": "ok"}
}
```

#### Cell Analyzer — `localhost:8081`

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/analyze` | Run full 20-well analysis, returns ranked results + base64 well images |
| `GET` | `/api/status` | Server health |

---

## Frontend (Flutter)

**Directory:** `frontend/`  
**Language:** Dart / Flutter (desktop target: macOS, Windows, Linux)

The app has three main panels accessible via the top navigation bar:

**1 · Environment Panel**  
Polls `GET /api/environment` every second. Displays 6 sensor cards with live sparklines (last 60 readings), colour-coded alarm states (green / amber / red), and an optional settings mode where targets can be adjusted via `+/-` controls (pushed to the server via `POST /api/targets`).

**2 · Protocol Run Panel**  
An 8-step state machine driven by a `Timer.periodic(1s)` inside Flutter. No backend calls are made during the run — the protocol logic is entirely client-side. Steps:

```
1. Sample Intake        (2 min)
2. Cell Dissociation    (5 min)
3. Droplet Generation   (3 min)
4. Drug Combination Loading (4 min)
5. Incubation           (10 min)
6. Fluorescence Imaging (5 min)
7. Data Analysis        (2 min)
8. Report Ready
```

Each active step shows a **live step animation** (custom Flutter `CustomPainter`) and a QC checklist note. Start/Pause/Abort controls are available. A "Skip Step" shortcut is included for demo/simulation purposes.

**3 · Oncology Panel**  
Locked until the protocol reaches the Imaging step. Then calls `GET /api/analyze` once and renders:
- A 20-well heatmap grid (green = high efficacy, red = low)
- A microscopy frame viewer per well
- A top-5 ranked drug sidebar
- A treatment recommendation banner

**Patient privacy:** Patient names are pseudonymised by default. The "Reveal" button shows the full name for 5 seconds and writes a timestamped entry to an in-memory audit log.

**PDF Report:** After a completed run, a full protocol report can be exported as a PDF (via the `printing` + `pdf` Flutter packages) including patient info, step durations, QC notes, and outcomes.

---

## Docker Setup

Each backend service has its own `Dockerfile` inside `backend/`. They compile from source using a multi-stage build:

```
Stage 1 (builder):  gcc + cmake + opencv → compile C++ binary
Stage 2 (runtime):  minimal base + copy binary → small final image
```

Both containers are orchestrated via `docker-compose.yml`:

```yaml
services:
  sensor-server:          # sensor_server.cpp
    build: ./backend/sensor_server
    ports: ["8080:8080"]
    volumes: ["./logs:/app/logs"]   # CSV logs persist on host

  cell-analyzer:          # cell_analyzer.cpp
    build: ./backend/cell_analyzer
    ports: ["8081:8081"]
```

The Flutter app connects to `localhost:8080` and `localhost:8081`. If a service is unreachable, the UI shows a "Disconnected" badge with a button to launch Docker.

---

## Getting Started

### Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| [Docker Desktop](https://www.docker.com/products/docker-desktop/) | ≥ 4.x | Run both C++ backends |
| [Flutter SDK](https://docs.flutter.dev/get-started/install) | ≥ 3.x | Build & run the desktop app |
| Dart SDK | included with Flutter | — |

> **No C++ compiler required on your machine** — the C++ code compiles inside Docker.

---

### Run with Docker (recommended)

**1. Clone the repo**
```bash
git clone https://github.com/matteomeister-engineer/therame-simulator.git
cd therame-simulator
```

**2. Start both backend services**
```bash
docker compose up --build
```

This compiles and launches:
- `sensor_server` → `http://localhost:8080`
- `cell_analyzer` → `http://localhost:8081`

You should see output like:
```
sensor-server  | Lab-on-Chip Monitor -> http://0.0.0.0:8080
cell-analyzer  | Oncology analyzer on http://0.0.0.0:8081
```

**3. Run the Flutter app**
```bash
cd frontend
flutter pub get
flutter run -d macos      # or: -d windows / -d linux
```

The app will launch and connect automatically. Green "Live" badges appear in the Environment and Oncology panels when the backends are reachable.

---

### Run manually (without Docker)

If you want to build and run the C++ servers directly:

**Sensor server**
```bash
# Requires: g++ with C++17, cpp-httplib header (already in backend/)
cd backend
g++ sensor_server.cpp -o sensor_server -std=c++17 -lpthread
./sensor_server
```

**Cell analyzer**
```bash
# Requires: g++ with C++17, OpenCV 4 installed
# macOS:   brew install opencv
# Ubuntu:  sudo apt install libopencv-dev
cd backend
g++ cell_analyzer.cpp -o cell_analyzer -std=c++17 \
    $(pkg-config --cflags --libs opencv4) -lpthread
./cell_analyzer
```

---

### Quick demo walkthrough

Once everything is running:

1. **Log in** with `admin` / `admin123`
2. **Select a patient** from the list
3. Go to the **Protocol** tab → click **Start Run**
4. Use **Skip Step** (simulation mode) to advance quickly through all 8 steps
5. Once **Fluorescence Imaging** completes, go to the **Oncology** tab
6. Click **Run Analysis** — the C++ server generates synthetic microscopy data
7. View the well heatmap, microscopy frames, and treatment recommendation
8. Go back to Protocol → **View Report** to export a PDF

---

## Project Structure

```
therame-simulator/
├── backend/
│   ├── sensor_server.cpp     # Environment monitoring server (port 8080)
│   │                         # Sensors, CSV logger, target control
│   ├── cell_analyzer.cpp     # Oncology analysis server (port 8081)
│   │                         # OpenCV image gen, blob detection, drug ranking
│   └── httplib.h             # Single-header HTTP library (cpp-httplib)
│
├── frontend/
│   ├── lib/
│   │   └── main.dart         # Entire Flutter app (~4300 lines)
│   │                         # Login, patient select, 3-panel dashboard,
│   │                         # protocol state machine, step animations,
│   │                         # PDF export, audit log
│   ├── pubspec.yaml          # Flutter dependencies
│   └── ...
│
├── docs/                     # Additional documentation / assets
│
├── docker-compose.yml        # Orchestrates both backend containers
├── .gitignore
└── README.md
```

---

## Key Dependencies

**Backend (C++)**
| Library | Use |
|---|---|
| [cpp-httplib](https://github.com/yhirose/cpp-httplib) | Single-header HTTP server (no Boost required) |
| [OpenCV 4](https://opencv.org/) | Image generation, blob detection, annotation |

**Frontend (Flutter/Dart)**
| Package | Use |
|---|---|
| `http` | HTTP client for backend polling |
| `fl_chart` | Sensor sparkline charts |
| `pdf` + `printing` | Protocol run PDF export |
| `window_manager` | Desktop window sizing and title |
| `path_provider` | PDF save location |
