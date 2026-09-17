// node --test herdr-plugins/artifacts/
import assert from "node:assert/strict";
import { mkdtempSync, writeFileSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { CREATED, normalize, scan, token } from "./artifacts.mjs";

const HOME = homedir();
const msg = (role, content, timestamp, extra = {}) => ({ type: "message", timestamp, message: { role, content, ...extra } });
const said = (text, t) => msg("assistant", [{ type: "text", text }], t);
const call = (id, command, t) => msg("assistant", [{ type: "toolCall", id, name: "bash", arguments: { command } }], t);
const result = (id, text, t) => msg("toolResult", [{ type: "text", text }], t, { toolCallId: id, toolName: "bash" });
const fixture = [
  { type: "session", cwd: "/Users/x/work/repo" },
  { type: "session_info", name: "fixture" },
  said("Working in ~/work/repo-worktrees/feat. Run log: /tmp/run.log", "2026-09-01T10:00:00.000Z"),
  said(
    [
      "PR is up: https://github.com/acme/repo/pull/123/files — see https://github.com/acme/repo/pull/123#issuecomment-99 too.",
      "Docs: https://docs.acme.dev/guide#section-2",
      "```",
      "gh pr view https://github.com/acme/repo/pull/999",
      "```",
      'Notebook "Rate limit budget" (`ci-rate-limit-notebook`) → https://app.datadoghq.com/notebook/15543987',
      "Dashboard `CI GitHub API rate limiting` created: https://app.datadoghq.com/dashboard/abc-def/ci",
      "Filed [Flaky test tracker](https://github.com/acme/repo/issues/7).",
      "Tracker: [PLAT-89](https://linear.app/acme/issue/PLAT-89/tracker) created for the rollout",
      `Postmortem: /tmp/postmortem.md; worktree ${HOME}/work/repo-worktrees/feat`,
    ].join("\n"),
    "2026-09-01T10:05:00.000Z",
  ),
  said(
    [
      "Notebook: **https://app.datadoghq.com/notebook/15543987**.", // emphasis glued to the URL, then the period
      "Ticket https://linear.app/acme/issue/PLAT-89 (bare, no slug); short report at /tmp/pr.md",
      "Cheat sheets live in ~/.config/cheat/*.md", // a glob is not a file
    ].join("\n"),
    "2026-09-01T10:05:30.000Z",
  ),
  call("c1", "gh pr create --title x --body-file /tmp/b.md", "2026-09-01T10:06:00.000Z"),
  result("c1", "https://github.com/acme/repo/pull/123\n\n[duration: 2.7s]", "2026-09-01T10:06:03.000Z"),
  // tool results that are not `gh pr|issue create` are what the agent read, not made
  call("c2", "gh pr list", "2026-09-01T10:07:00.000Z"),
  result("c2", "https://github.com/acme/repo/pull/555", "2026-09-01T10:07:01.000Z"),
];
const file = join(mkdtempSync(join(tmpdir(), "artifacts-")), "s.jsonl");
writeFileSync(file, fixture.map((e) => JSON.stringify(e)).join("\n") + "\n");
const { items, name, entries } = scan(file);
const by = (k) => items.filter((i) => i.kind === k);

test("session header", () => {
  assert.equal(name, "fixture");
  assert.equal(entries, fixture.length);
});

test("PR: /files, #issuecomment and gh pr create output fold into one row", () => {
  assert.deepEqual(by("PR").map((i) => [i.label, i.n, [...i.by].sort()]), [["acme/repo#123", 3, ["created", "said"]]]);
});

test("fenced code and plain tool results are skipped", () => {
  assert.ok(!items.some((i) => /pull\/(999|555)/.test(i.key)));
});

test("#fragment dropped, kind classification", () => {
  assert.equal(normalize("https://docs.acme.dev/guide#section-2"), "https://docs.acme.dev/guide");
  assert.deepEqual(
    items.map((i) => i.kind),
    ["PR", "issue", "notebook", "dashboard", "linear", "file", "file", "file", "worktree", "link"],
  );
});

test("markdown emphasis and punctuation glued to a URL, slugged and bare ids: one row each", () => {
  assert.equal(normalize("https://app.datadoghq.com/notebook/15543987**."), "https://app.datadoghq.com/notebook/15543987");
  assert.equal(normalize("https://linear.app/acme/issue/PLAT-89/tracker)**"), "https://linear.app/acme/issue/PLAT-89");
  assert.deepEqual(by("notebook").map((i) => [i.label, i.n]), [["app.datadoghq.com/notebook/15543987", 2]]);
  assert.deepEqual(by("linear").map((i) => [i.label, i.n]), [["PLAT-89", 2]]);
});

test("title order: quoted > longest backtick > link text unless #123/PLAT-89 > sentence", () => {
  assert.equal(by("notebook")[0].title, "Rate limit budget");
  assert.equal(by("dashboard")[0].title, "CI GitHub API rate limiting");
  assert.equal(by("issue")[0].title, "Flaky test tracker");
  assert.equal(by("linear")[0].title, "Tracker: PLAT-89 created for the rollout");
});

test("$HOME and ~ spellings of a worktree are one row", () => {
  assert.deepEqual(by("worktree").map((i) => [i.label, i.n]), [["~/work/repo-worktrees/feat", 2]]);
});

test("files: .log/.txt sort after .md even when mentioned first; short paths kept; globs dropped", () => {
  assert.deepEqual(by("file").map((i) => i.label), ["/tmp/postmortem.md", "/tmp/pr.md", "/tmp/run.log"]);
});

test("token: created kinds only, ≤ 80 chars", () => {
  assert.equal(token(items), "⎘ 1 PR · 1 issue · 1 notebook · 1 dashboard · 1 linear · 3 files · 1 worktree");
  const crowded = CREATED.map((kind) => ({ kind }));
  const t = token(crowded.flatMap((i) => Array(100).fill(i)));
  assert.ok(t.length <= 80 && t.startsWith("⎘ 100 PR · 100 issues") && t.endsWith("…"), t);
  assert.equal(token([{ kind: "link" }]), "");
});
