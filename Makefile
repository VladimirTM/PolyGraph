# PolyGraph: comenzile comune. `make help` le listează.
SHELL := /bin/bash
UV := uv run --project backend
PORT ?= 8000
# Simulatorul pentru check-ios: primul iPhone disponibil (se poate forța: make check-ios SIM="iPhone 16")
SIM ?= $(shell xcrun simctl list devices available 2>/dev/null | grep -m1 -oE 'iPhone [A-Za-z0-9 ]+' | sed 's/ *$$//')

.PHONY: help setup check check-contracts lint test check-ios models mock dev kb demo-b3 demo-warm demo-check review

help:
	@grep -E '^[a-z-]+:.*## ' Makefile | sed 's/:.*## /\t/' | column -t -s $$'\t'

setup: ## hook-urile git + mediul Python (uv)
	git config core.hooksPath .githooks
	chmod +x .githooks/*
	uv sync --project backend
	@echo "Gata. iOS: proiectul se deschide din app/PolyGraph.xcodeproj (vezi app/README.md)."

check: check-contracts lint test ## R1–R3 pentru contracte și Python (ce rulează și CI-ul)

check-contracts: ## R1: scheme, openapi.yaml, exemple, fixture-uri
	$(UV) python contracts/validate.py

lint: ## R2: ruff
	$(UV) ruff check backend contracts kb
	$(UV) ruff format --check backend contracts kb

test: ## R3: pytest
	cd backend && uv run pytest -q

check-ios: ## R2–R3 iOS: build + teste pe simulator (doar pe Mac)
	@test -d app/PolyGraph.xcodeproj || { echo "Lipsește app/PolyGraph.xcodeproj (se creează din Xcode, vezi app/README.md)."; exit 1; }
	cd app && xcodebuild test -project PolyGraph.xcodeproj -scheme PolyGraph \
		-destination 'platform=iOS Simulator,name=$(SIM)' -quiet

models: ## modelele Swift din contracts/schema (quicktype)
	mkdir -p app/PolyGraph/Models
	npx -y quicktype@23 --src-lang schema --lang swift --acronym-style original \
		-o app/PolyGraph/Models/Contracts.swift contracts/schema/*.schema.json
	@# quicktype numește tipurile anonime după schemă: `Result` ar ascunde Swift.Result în tot modulul
	perl -pi -e 's/\bResult\b/KBSearchHit/g; s/\bMedicationItemSchema\b/Substance/g' app/PolyGraph/Models/Contracts.swift
	@echo "Generat app/PolyGraph/Models/Contracts.swift (nu se editează de mână)."

mock: ## serverul mock pe 0.0.0.0:$(PORT) (fixture-urile din contracts/)
	@echo "Mock: http://$$(ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | cut -d' ' -f1):$(PORT)  (pacient pat_demo, token demo-token)"
	$(UV) uvicorn mock_server:app --app-dir backend --host 0.0.0.0 --port $(PORT) --reload

dev: ## backend-ul real (din B2)
	@test -f backend/polygraph/api/main.py || { echo "Backend-ul real vine la B2; până atunci: make mock"; exit 1; }
	$(UV) uvicorn polygraph.api.main:app --app-dir backend --host 0.0.0.0 --port $(PORT) --reload

kb: ## construiește kb/kb.sqlite din kb/raw (B1)
	@test -f kb/build.py || { echo "kb/build.py vine la B1"; exit 1; }
	$(UV) python kb/build.py

demo-b3: ## demonstrează B3 local cu OCR și DataMatrix sintetice
	PYTHONPATH=backend GEMINI_API_KEY= $(UV) --locked python demo/b3.py

demo-warm: ## pregătește cache-ul Gemini din fotografiile demo
	cd backend && uv run python -m polygraph.extract.gemini

demo-check: ## R4: scenariul demo prin API (B7); deocamdată nimic
	@echo "demo-check: vine la B7 (deocamdată no-op)"

review: ## R5: turul de review pe simulator, make review Q=Q1 (Q0)
	@test -x tools/review/run.sh || { echo "tools/review/run.sh vine la Q0"; exit 1; }
	tools/review/run.sh $(Q)
