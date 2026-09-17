#!/usr/bin/env node
// artifacts.mjs — what a pi session made, read from its transcript: PRs, issues, notebooks, dashboards,
// Linear tickets, Drops, report files, worktrees. Source is what the agent SAID (assistant text, fenced
// code skipped) plus the output of `gh pr|issue create`; tool results in general are what it read, not made.
//
//   artifacts.mjs <session.jsonl>... [--json]   shell: print the list for one or more transcripts
//   artifacts.mjs report [--all-panes]          herdr hook: sidebar token for the event's pane (or every pi pane)
//   artifacts.mjs show                          herdr pane: full list for the focused pane; any key closes it
//   artifacts.mjs open                          herdr action: open the `show` overlay over the focused pane
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, realpathSync } from "node:fs";
import { homedir } from "node:os";
import { basename } from "node:path";
import { fileURLToPath } from "node:url";

const HOME = homedir();
const URL_RE = /https?:\/\/[^\s<>"'`)\]]+/g;
// report-ish files the agent names to the user; code files are edits, not artifacts
const FILE_RE = /(?:~|\/(?:tmp|Users|home|private))\/[^\s<>"'`()\]:,*]*\.(?:md|txt|html|png|svg|patch|diff|log|csv)\b/g; // no globs
const WORKTREE_RE = /(?<![:/\w…])~?\/[^\s"'`()]+-worktrees\/[\w.-]+(?![<\w.-])/g; // no `…/x-worktrees/a`, no `pr-<N>`
const PLACEHOLDER = /\$\{|\.\.\.|…|example\.com|<[a-z]+>/i;
const TRAIL = /[*_.,;:!?]+$/; // sentence punctuation and markdown emphasis glued to a URL, in any order
// GitHub pull|issues and Linear issues cut after the id, so `/files`, `#issuecomment-…` and slugs fold into one row
const ID_URL = /^https?:\/\/(?:github\.com\/[^/]+\/[^/]+\/(?:pull|issues)\/\d+|linear\.app\/[^/]+\/issue\/[A-Za-z0-9]+-\d+)/;
const NOISY_FILE = /\.(?:txt|log)$/; // run/reviewer logs sort after reports and images

export const CREATED = ["PR", "issue", "notebook", "dashboard", "linear", "drop", "deploy", "file", "worktree"];
const OTHER = ["CI run", "github", "datadog", "slack", "notion", "link"];
const ORDER = [...CREATED, ...OTHER];

// Dedup key: trailing punctuation/markdown stripped, `#fragment` dropped, ids cut (ID_URL), `$HOME` → `~`.
export function normalize(raw) {
  let u = raw.replace(TRAIL, "");
  while (u.endsWith(")") && (u.match(/\(/g) ?? []).length < (u.match(/\)/g) ?? []).length) u = u.slice(0, -1).replace(TRAIL, "");
  if (!/^https?:/.test(u)) return u.replace(/^\/private\/tmp\//, "/tmp/").replace(new RegExp(`^${HOME}(?=/|$)`), "~");
  const id = u.match(ID_URL);
  return id ? id[0] : u.replace(/#.*$/, "").replace(/\/$/, "");
}

export function kind(u) {
  if (!/^https?:/.test(u)) return /-worktrees\/[\w.-]+$/.test(u) ? "worktree" : "file";
  let host, p;
  try { ({ host, pathname: p } = new URL(u)); } catch { return "link"; }
  if (host === "github.com") {
    if (/\/pull\/\d+/.test(p)) return "PR";
    if (/\/issues\/\d+/.test(p)) return "issue";
    if (/\/actions\/runs\//.test(p)) return "CI run";
    return "github";
  }
  if (host.endsWith("datadoghq.com")) return p.startsWith("/notebook") ? "notebook" : p.startsWith("/dashboard") ? "dashboard" : "datadog";
  if (host === "linear.app") return "linear";
  if (host.endsWith("slack.com")) return "slack";
  if (host.includes("notion")) return "notion";
  if (host.startsWith("drop.") || p.startsWith("/drops/")) return "drop"; // published report pages
  if (host.startsWith("deploy.")) return "deploy";
  return "link";
}

function label(u, k) {
  if (k === "PR" || k === "issue") return u.replace(/^https:\/\/github\.com\//, "").replace(/\/(pull|issues)\//, "#");
  if (k === "linear") return u.split("/").pop();
  if (k === "file" || k === "worktree") return u;
  return u.replace(/^https?:\/\//, "");
}

// Title from the line of first mention: "quoted" span > longest `backticked` span > markdown link text
// (unless it is just #123 / PLAT-89 / a URL) > the sentence minus the URL.
export function titleFor(line, raw) {
  const quoted = line.match(/[“"]([^”"]{8,})[”"]/);
  if (quoted) return clean(quoted[1]);
  const ticks = [...line.matchAll(/`([^`]{8,})`/g)].map((m) => m[1]).sort((a, b) => b.length - a.length);
  if (ticks.length) return clean(ticks[0]);
  const link = [...line.matchAll(/\[([^\]]{4,})\]\(([^)]+)\)/g)].find((m) => m[2] === raw);
  if (link && !/^#?\d+$|^https?:|^[A-Z]+-\d+$|^[\w/-]+#\d+$/.test(link[1])) return clean(link[1]);
  return clean(line.replace(/\[([^\]]*)\]\([^)]*\)/g, "$1").replace(raw, "").replace(/https?:\/\/\S+/g, ""));
}
const clean = (s) =>
  s.replace(/[*`#>|]/g, "").replace(/^[\s\W]*(?:✅|Done|Draft PR|PR is up|Notebook|Fixed|Added)?[\s\W—:-]*/u, "").replace(/\s+/g, " ").trim().slice(0, 90);

// PRs pr-watch tracks carry their real title (~/.local/state/pr-watch/track.json: {tracked: {key: {url, title}}}).
function prWatchTitles() {
  try {
    const { tracked } = JSON.parse(readFileSync(`${HOME}/.local/state/pr-watch/track.json`, "utf8"));
    return new Map(Object.values(tracked).map((t) => [t.url, t.title]));
  } catch {
    return new Map();
  }
}

export function scan(file) {
  const found = new Map(); // key → { kind, label, title, first, last, n, by }
  const add = (raw, line, when, by) => {
    const u = normalize(raw);
    if (PLACEHOLDER.test(u) || (/^https?:/.test(u) && u.length < 12)) return;
    const k = kind(u);
    const hit = found.get(u) ?? { key: u, kind: k, label: label(u, k), title: "", first: when, last: when, n: 0, by: new Set() };
    hit.n++;
    hit.last = when;
    hit.by.add(by);
    if (!hit.title && by === "said") hit.title = titleFor(line, raw);
    found.set(u, hit);
  };
  const mine = (text, when, by) => {
    let fenced = false;
    for (const line of text.split("\n")) {
      if (/^\s*```/.test(line)) { fenced = !fenced; continue; }
      if (fenced && by === "said") continue; // code blocks are examples, not artifacts
      for (const re of [URL_RE, FILE_RE, WORKTREE_RE]) for (const m of line.matchAll(re)) add(m[0], line, when, by);
    }
  };
  let name = "", cwd = "", entries = 0;
  const calls = new Map(); // toolCallId → bash command, to allow-list `gh pr|issue create` output
  for (const row of readFileSync(file, "utf8").split("\n")) {
    if (!row) continue;
    let e;
    try { e = JSON.parse(row); } catch { continue; }
    entries++;
    if (e.type === "session") cwd = e.cwd ?? "";
    if (e.type === "session_info") name = e.name ?? "";
    if (e.type !== "message") continue;
    const when = e.timestamp ?? "";
    const { role, content } = e.message ?? {};
    if (role === "assistant") for (const c of content ?? []) {
      if (c.type === "text") mine(c.text, when, "said");
      if (c.type === "toolCall" && c.name === "bash") calls.set(c.id, c.arguments?.command ?? "");
    }
    if (role === "toolResult" && /\bgh (pr|issue) create\b/.test(calls.get(e.message.toolCallId) ?? "")) {
      mine((content ?? []).flatMap((c) => (c.type === "text" ? [c.text] : [])).join("\n"), when, "created");
    }
  }
  const known = prWatchTitles();
  for (const [u, hit] of found) if (known.has(u)) hit.title = known.get(u);
  const fileRank = (i) => (i.kind === "file" && NOISY_FILE.test(i.key) ? 1 : 0);
  const items = [...found.values()].sort(
    (a, b) => ORDER.indexOf(a.kind) - ORDER.indexOf(b.kind) || fileRank(a) - fileRank(b) || a.first.localeCompare(b.first),
  );
  return { file, name, cwd, entries, items };
}

// Sidebar token: created kinds only, ≤ 80 chars (herdr's cap), e.g. `⎘ 5 PR · 1 notebook · 6 files`.
export function token(items) {
  const counts = new Map();
  for (const i of items) if (CREATED.includes(i.kind)) counts.set(i.kind, (counts.get(i.kind) ?? 0) + 1);
  const parts = [...counts].map(([k, n]) => `${n} ${n === 1 || k === "PR" || k === "linear" ? k : k + "s"}`);
  if (!parts.length) return "";
  let text = `⎘ ${parts.join(" · ")}`;
  while (text.length > 80) { parts.pop(); text = `⎘ ${parts.join(" · ")} …`; }
  return text;
}

const OSC8 = (url, text) => `\x1b]8;;${url}\x1b\\${text}\x1b]8;;\x1b\\`;
const dim = (s) => `\x1b[2m${s}\x1b[0m`;

export function render(s, { links = false, cols = 200 } = {}) {
  const out = [`${s.name || basename(s.file)}  (${s.cwd}, ${s.entries} entries, ${s.items.length} artifacts)`];
  const lw = Math.min(48, Math.max(0, ...s.items.map((i) => i.label.length)));
  const room = Math.max(20, cols - (lw + 40));
  let other = false;
  for (const i of s.items) {
    if (!other && OTHER.includes(i.kind)) { other = true; out.push(dim("— other links —")); }
    const lab = (links && /^https?:/.test(i.key) ? OSC8(i.key, i.label) : i.label) + " ".repeat(Math.max(0, lw - i.label.length));
    const row = `${i.kind.padEnd(9)} ${lab} ${i.title.slice(0, room).padEnd(Math.min(room, 70))} ×${String(i.n).padStart(2)}  ${i.first.slice(5, 16).replace("T", " ")}`;
    out.push(other ? dim(row) : row);
  }
  return out.join("\n");
}

// ---- herdr glue -------------------------------------------------------------------------------------------
const HERDR = process.env.HERDR_BIN_PATH ?? "herdr";
function herdr(...args) {
  const r = spawnSync(HERDR, args, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
  if (r.status !== 0) throw new Error(`${HERDR} ${args.slice(0, 3).join(" ")}: ${(r.stderr || r.stdout || r.error?.message || "").trim()}`);
  return r.stdout.trim() ? JSON.parse(r.stdout).result : undefined; // report-metadata prints nothing
}

const sessionFile = (pane) => {
  const s = pane?.agent_session;
  return s?.agent === "pi" && s.kind === "path" && existsSync(s.value) ? s.value : null;
};

function reportPane(pane) {
  const file = sessionFile(pane);
  if (!file) return;
  const text = token(scan(file).items);
  herdr("pane", "report-metadata", pane.pane_id, "--source", "tribble.artifacts", "--seq", String(Date.now()),
    ...(text ? ["--token", `artifacts=${text}`] : ["--clear-token", "artifacts"]));
}

function focusedPaneId() {
  const ctx = JSON.parse(process.env.HERDR_PLUGIN_CONTEXT_JSON ?? "{}");
  return ctx.focused_pane_id ?? process.env.HERDR_PANE_ID;
}

function main(argv) {
  const [mode, ...rest] = argv;
  if (mode === "report") {
    if (rest.includes("--all-panes")) for (const p of herdr("pane", "list").panes) reportPane(p);
    else {
      const ev = JSON.parse(process.env.HERDR_PLUGIN_EVENT_JSON ?? "{}");
      if (["idle", "done", "blocked"].includes(ev.agent_status) && ev.pane_id) reportPane(herdr("pane", "get", ev.pane_id).pane);
    }
    return;
  }
  if (mode === "open") { // overlays always open over the active pane; herdr rejects --target-pane for them
    herdr("plugin", "pane", "open", "--plugin", "tribble.artifacts", "--entrypoint", "list", "--focus");
    return;
  }
  if (mode === "show") {
    const id = focusedPaneId();
    const file = id && sessionFile(herdr("pane", "get", id).pane);
    console.log(file ? render(scan(file), { links: true, cols: process.stdout.columns }) : `no pi session on pane ${id ?? "?"}`);
    if (!process.stdin.isTTY) return;
    process.stdout.write(dim("\n— any key closes —"));
    process.stdin.setRawMode(true);
    process.stdin.resume();
    process.stdin.once("data", () => process.exit(0));
    return;
  }
  const files = argv.filter((a) => !a.startsWith("--"));
  if (!files.length) { console.error("usage: artifacts.mjs <session.jsonl>... [--json] | report [--all-panes] | show | open"); process.exit(2); }
  for (const f of files) {
    const s = scan(f);
    if (argv.includes("--json")) console.log(JSON.stringify({ ...s, token: token(s.items), items: s.items.map((i) => ({ ...i, by: [...i.by] })) }, null, 1));
    else console.log(`\n${render(s, { links: process.stdout.isTTY, cols: process.stdout.columns })}`);
  }
}

if (process.argv[1] && realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) main(process.argv.slice(2));
