"""Graful terapeutic al pacientului (plan 5.6), exportat în formatul Cytoscape (`elements`: nodes + edges).

Noduri: pacientul, produsele, substanțele, clasele ATC4, alimentele din alertele food, simptomele raportate în
ultimele 7 zile. Muchii: takes, contains, in_class, interacts (cu alert_id; `unknown` = pereche DDInter fără nivel,
gri, fără alertă), food_interaction, reported, possibly_related (simptom ↔ substanță cu acel efect advers).
"""

from __future__ import annotations

from datetime import date, datetime, timedelta
from typing import TYPE_CHECKING, Any

from polygraph.graph.atc_labels import atc4_label
from polygraph.kb import SEV_RANK

if TYPE_CHECKING:  # evită importul circular engine ↔ graph
    from polygraph.engine.context import Component, Ctx

Json = dict[str, Any]


def substance_node_id(c: Component) -> str:
    if c.atc and len(c.atc) == 7:
        return f"s:{c.atc}"
    return "s:" + c.key.split(":", 1)[1].replace(" ", "_")


def _checkin_date(ci: Json) -> date | None:
    try:
        return datetime.fromisoformat(str(ci.get("at")).replace("Z", "+00:00")).date()
    except ValueError:
        return None


def build(ctx: Ctx, alerts: list[Json], checkins: list[Json]) -> Json:
    nodes: dict[str, Json] = {"p": {"id": "p", "type": "patient", "label": ctx.patient.get("name") or "Pacient"}}
    edges: list[Json] = []
    edge_keys: set[tuple] = set()

    def edge(source: str, target: str, type_: str, **extra: Any) -> None:
        key = (source, target, type_, extra.get("alert_id"))
        if key in edge_keys:
            return
        edge_keys.add(key)
        edges.append({"source": source, "target": target, "type": type_, **extra})

    worst_med: dict[str, str] = {}
    for a in alerts:
        for mid in a["med_ids"]:
            if mid not in worst_med or SEV_RANK[a["severity"]] < SEV_RANK[worst_med[mid]]:
                worst_med[mid] = a["severity"]

    sub_nodes_of_med: dict[str, list[str]] = {}
    for m in ctx.meds:
        prod = m.get("product") or {}
        label = " ".join(x for x in (prod.get("brand"), prod.get("strength_text")) if x) or m["id"]
        node: Json = {
            "id": m["id"],
            "type": "product",
            "label": label,
            "prescriber": (m.get("prescriber") or {}).get("specialty"),
        }
        if m["id"] in worst_med:
            node["severity"] = worst_med[m["id"]]
        nodes[m["id"]] = node
        edge("p", m["id"], "takes")

    for c in ctx.components:
        sid = substance_node_id(c)
        nodes.setdefault(sid, {"id": sid, "type": "substance", "label": c.name_ro})
        edge(c.med_id, sid, "contains")
        sub_nodes_of_med.setdefault(c.med_id, []).append(sid)
        if c.atc4:
            cid = f"c:{c.atc4}"
            nodes.setdefault(cid, {"id": cid, "type": "atc_class", "label": atc4_label(c.atc4)})
            edge(sid, cid, "in_class")

    def pair_nodes(a_mid: str, b_mid: str) -> tuple[str, str] | None:
        for x in sub_nodes_of_med.get(a_mid, []):
            for y in sub_nodes_of_med.get(b_mid, []):
                if x != y:
                    return x, y
        return None

    def mark(node_id: str, severity: str) -> None:
        n = nodes[node_id]
        if "severity" not in n or SEV_RANK[severity] < SEV_RANK[n["severity"]]:
            n["severity"] = severity

    for a in alerts:
        if a["kind"] == "ddi" and len(a["med_ids"]) == 2:
            pn = pair_nodes(*a["med_ids"])
            if pn:
                edge(pn[0], pn[1], "interacts", severity=a["severity"], alert_id=a["id"])
                mark(pn[0], a["severity"])
                mark(pn[1], a["severity"])
        elif a["kind"] == "food":
            food = a["id"].rsplit("_", 1)[-1]
            fid = f"f:{food}"
            label = ctx.kb.foods.get(food, {}).get("label_ro", food)
            nodes.setdefault(fid, {"id": fid, "type": "food", "label": label})
            for mid in a["med_ids"]:
                for sid in sub_nodes_of_med.get(mid, [])[:1]:
                    edge(sid, fid, "food_interaction", severity=a["severity"], alert_id=a["id"])

    for a, b in ctx.unknown_pairs:  # perechi DDInter fără nivel: muchie gri, fără alertă
        x, y = substance_node_id(a), substance_node_id(b)
        if x != y and not any(e["type"] == "interacts" and {e["source"], e["target"]} == {x, y} for e in edges):
            edge(x, y, "interacts", severity="unknown", alert_id=None)

    since = ctx.today - timedelta(days=7)
    for ci in checkins:
        d = _checkin_date(ci)
        if d is None or not (since <= d <= ctx.today):
            continue
        for s in ci.get("symptoms") or []:
            yid = f"y:{s['code']}"
            nodes.setdefault(yid, {"id": yid, "type": "symptom", "label": s.get("label") or s["code"]})
            edge("p", yid, "reported")
            for c in ctx.components:
                if c.sub and s["code"] in ctx.kb.adverse.get(c.sub.id, ()):
                    edge(yid, substance_node_id(c), "possibly_related")

    for i, e in enumerate(edges):
        e["id"] = f"e{i}"
    return {"nodes": [{"data": n} for n in nodes.values()], "edges": [{"data": e} for e in edges]}
