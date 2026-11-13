from fastapi.testclient import TestClient

from mock_server import PLACEHOLDER
from polygraph.api import main


def test_public_media_fallback_and_name_validation(tmp_path, monkeypatch):
    monkeypatch.setenv("PG_MEDIA_DIR", str(tmp_path / "uploads"))
    with TestClient(main.app) as client:
        for name in ("med_01..jpg", "other.jpg", "med_01%2Fmed_02.jpg"):
            assert client.get(f"/media/{name}").status_code in (404, 422)
        response = client.get("/media/med_01.jpg")
        assert response.status_code == 200
        assert response.headers["content-type"] == "image/png"
        assert response.content == PLACEHOLDER
