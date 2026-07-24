#!/usr/bin/env python3
"""Render and run the multi-role test matrix.

The matrix lives in docs/testing/multi-role-test-matrix.yaml. This script turns it
into the things a small team can actually use against a build: a filtered checklist,
a CSV for a spreadsheet, GitHub issues, and a release gate that fails when the
product parameters the tests depend on have not been signed off.

  ./scripts/testmatrix.py validate
  ./scripts/testmatrix.py params
  ./scripts/testmatrix.py list --gate blocker --kind negative
  ./scripts/testmatrix.py md --suite AUTHZ --suite MOB -o /tmp/gates.md
  ./scripts/testmatrix.py csv > /tmp/matrix.csv
  ./scripts/testmatrix.py issues --repo BeauAccessSolutions/kindredaccess --gate blocker
  ./scripts/testmatrix.py gate            # non-zero if params are unresolved

Issue creation is a dry run unless --execute is passed.
"""

from __future__ import annotations

import argparse
import csv
import io
import re
import shlex
import subprocess
import sys
from pathlib import Path

import yaml

DEFAULT_MATRIX = Path(__file__).resolve().parent.parent / "docs" / "testing" / "multi-role-test-matrix.yaml"

GATE_ORDER = {"blocker": 0, "required": 1, "recommended": 2}
REQUIRED_TEST_FIELDS = ("id", "title", "gate", "kind", "surfaces", "steps", "pass", "fail", "automation")
VALID_KINDS = {"positive", "negative"}
PLACEHOLDER = re.compile(r"\{(P\d+)\.([a-z0-9_]+)\}")


def load(path: Path) -> dict:
    with path.open() as fh:
        return yaml.safe_load(fh)


def param_index(doc: dict) -> dict:
    """Map the short key (P1) to the full param entry, so tests can write {P1.idle_default}."""
    return {key.split("_", 1)[0]: {"key": key, **value} for key, value in doc.get("params", {}).items()}


def resolve(text, params: dict) -> str:
    """Substitute {P1.field} references with the current parameter value."""
    if not isinstance(text, str):
        return text

    def sub(match: re.Match) -> str:
        short, field = match.group(1), match.group(2)
        entry = params.get(short)
        if not entry:
            return match.group(0)
        value = entry.get("values", {}).get(field)
        return match.group(0) if value is None else str(value)

    return PLACEHOLDER.sub(sub, text)


def iter_tests(doc: dict):
    for suite in doc.get("suites", []):
        for test in suite.get("tests", []):
            yield suite, test


def select(doc: dict, args) -> list[tuple[dict, dict]]:
    rows = []
    for suite, test in iter_tests(doc):
        if args.suite and suite["id"] not in args.suite:
            continue
        if args.gate and test["gate"] not in args.gate:
            continue
        if args.kind and test["kind"] != args.kind:
            continue
        if args.surface and args.surface not in test.get("surfaces", []):
            continue
        if args.automation and test.get("automation") != args.automation:
            continue
        rows.append((suite, test))
    rows.sort(key=lambda pair: (GATE_ORDER.get(pair[1]["gate"], 9), pair[1]["id"]))
    return rows


# --------------------------------------------------------------------------- validate


def cmd_validate(doc: dict, params: dict, args) -> int:
    problems: list[str] = []
    seen: set[str] = set()

    for suite, test in iter_tests(doc):
        tid = test.get("id", "<missing id>")
        for field in REQUIRED_TEST_FIELDS:
            if not test.get(field):
                problems.append(f"{tid}: missing required field '{field}'")
        if tid in seen:
            problems.append(f"{tid}: duplicate id")
        seen.add(tid)
        if not tid.startswith(suite["id"] + "-"):
            problems.append(f"{tid}: id does not match suite prefix '{suite['id']}-'")
        if test.get("gate") not in GATE_ORDER:
            problems.append(f"{tid}: unknown gate '{test.get('gate')}'")
        if test.get("kind") not in VALID_KINDS:
            problems.append(f"{tid}: unknown kind '{test.get('kind')}'")
        for ref in test.get("params", []):
            if ref not in doc.get("params", {}):
                problems.append(f"{tid}: references unknown parameter '{ref}'")
        blob = " ".join(str(v) for v in test.values() if isinstance(v, str))
        blob += " " + " ".join(str(s) for s in test.get("steps", []))
        for short, field in PLACEHOLDER.findall(blob):
            entry = params.get(short)
            if not entry:
                problems.append(f"{tid}: placeholder {{{short}.{field}}} has no matching parameter")
            elif field not in entry.get("values", {}):
                problems.append(f"{tid}: placeholder {{{short}.{field}}} is not a field of {entry['key']}")

    for name, entry in doc.get("params", {}).items():
        if not entry.get("rationale"):
            problems.append(f"{name}: missing rationale (ASVS v5 expects a documented justification)")
        if not entry.get("status"):
            problems.append(f"{name}: missing status")

    if problems:
        for line in problems:
            print(f"FAIL  {line}", file=sys.stderr)
        print(f"\n{len(problems)} problem(s).", file=sys.stderr)
        return 1

    total = sum(1 for _ in iter_tests(doc))
    blockers = sum(1 for _, t in iter_tests(doc) if t["gate"] == "blocker")
    print(f"OK  {total} tests across {len(doc['suites'])} suites, {blockers} ship-blocking.")
    return 0


# --------------------------------------------------------------------------- params


def cmd_params(doc: dict, params: dict, args) -> int:
    unresolved = []
    for name, entry in doc.get("params", {}).items():
        status = entry.get("status", "?")
        marker = "OK " if status == "adopted" else "!! "
        if status != "adopted":
            unresolved.append(name)
        print(f"{marker}{name}  [{status}]")
        for field, value in entry.get("values", {}).items():
            print(f"      {field}: {value}")
        if entry.get("open_question"):
            print(f"      OPEN: {' '.join(entry['open_question'].split())}")
        print()
    if unresolved:
        print(f"{len(unresolved)} parameter(s) not yet adopted: {', '.join(unresolved)}")
    return 0


def cmd_gate(doc: dict, params: dict, args) -> int:
    """Release gate: every parameter the blocking tests depend on must be adopted."""
    needed = set()
    for _, test in iter_tests(doc):
        if test["gate"] == "blocker":
            needed.update(test.get("params", []))
    unresolved = [name for name in sorted(needed) if doc["params"][name].get("status") != "adopted"]
    if unresolved:
        print("Blocking tests depend on parameters that have not been signed off:", file=sys.stderr)
        for name in unresolved:
            print(f"  - {name} [{doc['params'][name]['status']}]", file=sys.stderr)
        print("\nSet status: adopted in the matrix once the decision is made and recorded.", file=sys.stderr)
        return 1
    print(f"OK  all {len(needed)} parameters behind blocking tests are adopted.")
    return 0


# --------------------------------------------------------------------------- render


def render_test(suite: dict, test: dict, params: dict) -> str:
    out = io.StringIO()
    kind = "negative test" if test["kind"] == "negative" else "positive test"
    out.write(f"#### `{test['id']}` — {test['title']}\n\n")
    out.write(f"**{test['gate'].upper()}** · {kind} · {', '.join(test['surfaces'])} · {test['automation']}\n\n")
    if test.get("setup"):
        out.write(f"*Setup:* {resolve(test['setup'], params).strip()}\n\n")
    out.write("*Steps:*\n\n")
    for step in test["steps"]:
        out.write(f"1. {resolve(step, params).strip()}\n")
    out.write(f"\n- [ ] **PASS** — {resolve(test['pass'], params).strip()}\n")
    out.write(f"- [ ] **FAIL** — {resolve(test['fail'], params).strip()}\n")
    if test.get("note"):
        out.write(f"\n> {resolve(test['note'], params).strip()}\n")
    if test.get("refs"):
        out.write(f"\n*Refs:* {'; '.join(test['refs'])}\n")
    return out.getvalue()


def cmd_md(doc: dict, params: dict, args) -> int:
    rows = select(doc, args)
    out = io.StringIO()
    out.write("# Multi-role test matrix — run sheet\n\n")
    out.write(f"Generated from `docs/testing/multi-role-test-matrix.yaml` (v{doc['version']}, {doc['updated']}).\n\n")
    counts = {gate: sum(1 for _, t in rows if t["gate"] == gate) for gate in GATE_ORDER}
    out.write(f"{len(rows)} tests selected — {counts['blocker']} blocker, {counts['required']} required, "
              f"{counts['recommended']} recommended.\n\n")
    current = None
    for suite, test in sorted(rows, key=lambda p: (p[0]["id"], GATE_ORDER[p[1]["gate"]], p[1]["id"])):
        if suite["id"] != current:
            current = suite["id"]
            out.write(f"\n### {suite['id']} — {suite['name']}\n\n")
        out.write(render_test(suite, test, params))
        out.write("\n")
    text = out.getvalue()
    if args.output:
        Path(args.output).write_text(text)
        print(f"wrote {args.output} ({len(rows)} tests)")
    else:
        sys.stdout.write(text)
    return 0


def cmd_list(doc: dict, params: dict, args) -> int:
    rows = select(doc, args)
    for suite, test in rows:
        flag = "!" if test["kind"] == "negative" else " "
        print(f"{test['gate']:<12}{flag} {test['id']:<10} {test['title']}")
    print(f"\n{len(rows)} tests.")
    return 0


def cmd_csv(doc: dict, params: dict, args) -> int:
    writer = csv.writer(sys.stdout)
    writer.writerow(["id", "suite", "title", "gate", "kind", "surfaces", "automation",
                     "params", "pass_condition", "fail_condition", "refs", "result", "run_by", "run_on", "evidence"])
    for suite, test in select(doc, args):
        writer.writerow([
            test["id"], suite["id"], test["title"], test["gate"], test["kind"],
            "|".join(test["surfaces"]), test["automation"], "|".join(test.get("params", [])),
            " ".join(resolve(test["pass"], params).split()),
            " ".join(resolve(test["fail"], params).split()),
            "; ".join(test.get("refs", [])),
            "", "", "", "",
        ])
    return 0


# --------------------------------------------------------------------------- issues


def cmd_issues(doc: dict, params: dict, args) -> int:
    rows = select(doc, args)
    if not rows:
        print("nothing selected", file=sys.stderr)
        return 1
    for suite, test in rows:
        labels = ["test-matrix", f"gate:{test['gate']}", f"suite:{suite['id'].lower()}"]
        if test["kind"] == "negative":
            labels.append("negative-test")
        body = render_test(suite, test, params)
        body += ("\n---\n\nGenerated from `docs/testing/multi-role-test-matrix.yaml` in "
                 "`bas-platform`. Edit the matrix, not this issue — re-running the generator "
                 "is how this text changes.\n")
        cmd = ["gh", "issue", "create", "--repo", args.repo,
               "--title", f"[{test['id']}] {test['title']}",
               "--body", body, "--label", ",".join(labels)]
        if args.execute:
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode != 0:
                print(f"FAILED {test['id']}: {result.stderr.strip()}", file=sys.stderr)
                return result.returncode
            print(f"{test['id']}  {result.stdout.strip()}")
        else:
            print(" ".join(shlex.quote(part) for part in cmd))
    if not args.execute:
        print(f"\n# dry run — {len(rows)} issue(s). Re-run with --execute to create them.", file=sys.stderr)
    return 0


# --------------------------------------------------------------------------- cli


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--matrix", type=Path, default=DEFAULT_MATRIX)
    sub = parser.add_subparsers(dest="command", required=True)

    def add_filters(p):
        p.add_argument("--suite", action="append", help="suite id, repeatable (SESS, AUTHZ, ...)")
        p.add_argument("--gate", action="append", choices=list(GATE_ORDER), help="repeatable")
        p.add_argument("--kind", choices=sorted(VALID_KINDS))
        p.add_argument("--surface", help="web | mobile | api | process")
        p.add_argument("--automation", help="e2e | integration | unit | manual | ...")

    sub.add_parser("validate").set_defaults(func=cmd_validate)
    sub.add_parser("params").set_defaults(func=cmd_params)
    sub.add_parser("gate").set_defaults(func=cmd_gate)

    for name, func in (("list", cmd_list), ("csv", cmd_csv)):
        p = sub.add_parser(name)
        add_filters(p)
        p.set_defaults(func=func)

    p_md = sub.add_parser("md")
    add_filters(p_md)
    p_md.add_argument("-o", "--output")
    p_md.set_defaults(func=cmd_md)

    p_issues = sub.add_parser("issues")
    add_filters(p_issues)
    p_issues.add_argument("--repo", required=True, help="owner/name")
    p_issues.add_argument("--execute", action="store_true", help="actually create the issues")
    p_issues.set_defaults(func=cmd_issues)

    args = parser.parse_args()
    for attr in ("suite", "gate", "kind", "surface", "automation"):
        if not hasattr(args, attr):
            setattr(args, attr, None)

    doc = load(args.matrix)
    return args.func(doc, param_index(doc), args)


if __name__ == "__main__":
    sys.exit(main())
