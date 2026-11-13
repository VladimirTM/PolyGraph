"""B6: pagina farmacistului / medicului, versiunea de tipărit și graful pentru WKWebView (Jinja2 + un singur CSS)."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from jinja2 import Environment, FileSystemLoader, select_autoescape

HERE = Path(__file__).resolve().parent
STATIC_DIR = HERE / "static"

_env = Environment(
    loader=FileSystemLoader(HERE / "templates"),
    autoescape=select_autoescape(["html"]),
    trim_blocks=True,
    lstrip_blocks=True,
)


def render(template: str, **context: Any) -> str:
    return _env.get_template(template).render(**context)


__all__ = ["STATIC_DIR", "render"]
