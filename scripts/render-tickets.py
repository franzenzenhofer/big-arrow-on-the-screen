#!/usr/bin/env python3
"""Render docs/plan/TICKETS.md and docs/plan/report.html from docs/plan/tickets.json, the single
source of truth for tickets. Never edit the two outputs by hand.

Usage: scripts/render-tickets.py
"""
from __future__ import annotations

import html
import json
import re
from collections import Counter
from pathlib import Path

PLAN = Path(__file__).resolve().parent.parent / "docs" / "plan"
STATUS_LABEL = {"done": "Done", "later": "Later", "not now": "Not now"}


def load() -> dict:
    return json.loads((PLAN / "tickets.json").read_text())


def tickets_of(data: dict, milestone: str) -> list[dict]:
    return [t for t in data["tickets"] if t["milestone"] == milestone]


def markdown(data: dict) -> str:
    counts = Counter(t["status"] for t in data["tickets"])
    summary = ", ".join(f"{n} {STATUS_LABEL[s].lower()}" for s, n in counts.items())
    lines = [
        "# Tickets", "",
        f"Generated from `tickets.json` by `scripts/render-tickets.py`. {len(data['tickets'])} tickets: {summary}.", "",
    ]
    for milestone in data["milestones"]:
        lines += [f"## {milestone['title']}", "", milestone["description"], ""]
        for ticket in tickets_of(data, milestone["key"]):
            lines += [f"### {ticket['key']} {ticket['title']}", ""]
            meta = f"**Status: {STATUS_LABEL[ticket['status']]}**"
            if ticket.get("issue"):
                meta += f" · Issue: {ticket['issue']}"
            labels = " ".join(f"`{label}`" for label in ticket["labels"])
            lines += [meta + "  ", f"Labels: {labels}", "", f"**Outcome**: {ticket['outcome']}", "", ticket["body"], ""]
    return "\n".join(lines)


def inline(text: str) -> str:
    escaped = html.escape(text)
    escaped = re.sub(r"`([^`]+)`", r"<code>\1</code>", escaped)
    escaped = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", escaped)
    return re.sub(r"(https://[^\s<)]+)", r'<a href="\1">\1</a>', escaped)


def block(text: str) -> str:
    parts = []
    for paragraph in text.split("\n\n"):
        rows = paragraph.split("\n")
        items = [r[2:] for r in rows if r.startswith("- ")]
        heads = [inline(r) for r in rows if not r.startswith("- ")]
        parts += [f"<p>{h}</p>" for h in heads]
        if items:
            parts.append("<ul>" + "".join(f"<li>{inline(i)}</li>" for i in items) + "</ul>")
    return "".join(parts)


STYLE = """
:root{--bg:#fbfaf7;--fg:#1a1a1a;--muted:#555;--accent:#ff4422;--card:#fff;--line:#e6e2da;--code:#f1efe9;--done:#d6f5dd;--done-fg:#0b5a1f;--later:#fff0c2;--later-fg:#6a4b00}
@media (prefers-color-scheme:dark){:root:not([data-theme=light]){--bg:#151515;--fg:#eee;--muted:#aaa;--card:#1f1f1f;--line:#333;--code:#2a2a2a;--done:#123d1c;--done-fg:#bff0cb;--later:#3d3210;--later-fg:#f5e3a6}}
:root[data-theme=dark]{--bg:#151515;--fg:#eee;--muted:#aaa;--card:#1f1f1f;--line:#333;--code:#2a2a2a;--done:#123d1c;--done-fg:#bff0cb;--later:#3d3210;--later-fg:#f5e3a6}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:17px/1.55 -apple-system,"SF Pro Text",Helvetica,Arial,sans-serif;padding:0 16px}
main{max-width:960px;margin:0 auto;padding:32px 0 80px}h1{font-size:40px;line-height:1.1;margin:0 0 8px}
h2{font-size:28px;margin:48px 0 8px;border-top:3px solid var(--accent);padding-top:16px}h3{font-size:21px;margin:0 0 6px}
.sub{color:var(--muted);font-size:18px}article{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:18px 20px;margin:14px 0}
.key{display:inline-block;background:var(--accent);color:#fff;border-radius:8px;padding:0 10px;font-weight:800;margin-right:6px}
.status{display:inline-block;border-radius:999px;padding:2px 12px;font-size:16px;font-weight:700;background:var(--later);color:var(--later-fg)}
.status.done{background:var(--done);color:var(--done-fg)}.outcome{border-left:4px solid var(--accent);padding-left:12px}
code{background:var(--code);border-radius:6px;padding:1px 6px;font-size:16px}a{color:inherit}
"""


def report(data: dict) -> str:
    counts = Counter(t["status"] for t in data["tickets"])
    summary = " · ".join(f"{n} {STATUS_LABEL[s].lower()}" for s, n in counts.items())
    body = [f"<h1>bigarrow tickets</h1><p class=sub>{len(data['tickets'])} tickets: {summary}. Generated from tickets.json.</p>"]
    for milestone in data["milestones"]:
        body.append(f"<h2>{html.escape(milestone['title'])}</h2><p>{inline(milestone['description'])}</p>")
        for t in tickets_of(data, milestone["key"]):
            status = "done" if t["status"] == "done" else "open"
            issue = f' · <a href="{t["issue"]}">issue</a>' if t.get("issue") else ""
            body.append(
                f"<article><h3><span class=key>{t['key']}</span>{inline(t['title'])}</h3>"
                f"<p><span class='status {status}'>{STATUS_LABEL[t['status']]}</span>{issue}</p>"
                f"<p class=outcome>{inline(t['outcome'])}</p>{block(t['body'])}</article>"
            )
    return (
        '<!doctype html><html lang="en"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1"><title>Big Arrow Tickets</title>'
        f"<style>{STYLE}</style></head><body><main>{''.join(body)}</main></body></html>\n"
    )


def main() -> None:
    data = load()
    (PLAN / "TICKETS.md").write_text(markdown(data))
    (PLAN / "report.html").write_text(report(data))
    print(PLAN / "TICKETS.md")
    print(PLAN / "report.html")


if __name__ == "__main__":
    main()
