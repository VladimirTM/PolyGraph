# backend/: FastAPI, Python 3.12, uv (Dev B)

- `mock_server.py`: mock-ul P0, servește `contracts/fixtures/` pe toate rutele (`make mock`). Pacient `pat_demo`, token `demo-token`.
- `polygraph/{api,extract,engine,graph,schedule,voice,share,store}/`: backend-ul real, din B2 încolo.
- `tests/`: `make test` (contracte, mock, hook-ul de commit; apoi golden-urile motorului).
