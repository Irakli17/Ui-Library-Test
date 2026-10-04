#!/usr/bin/env node
/**
 * Vantage · tools/docs-check.mjs
 * ------------------------------------------------------------------
 * The documentation page is interactive, which means it is software, which
 * means it can be wrong. This checks the contract between the page and the
 * scripts that drive it — the class of bug that a browser console only
 * reports if you happen to click the right thing.
 *
 * It is a static check on purpose: no browser, no server, runs in CI in
 * milliseconds. `node tools/docs-check.mjs` — exits non-zero on a failure.
 *
 *   node tools/docs-check.mjs           check
 *   node tools/docs-check.mjs --verbose list every assertion
 */

import { readFileSync, existsSync, mkdtempSync, copyFileSync, rmSync } from "node:fs";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { tmpdir } from "node:os";
import { execFileSync } from "node:child_process";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const DOCS = join(ROOT, "docs");
const VERBOSE = process.argv.includes("--verbose");

let failures = 0;
let checks = 0;

function check(label, condition, detail = "") {
	checks += 1;
	if (condition) {
		if (VERBOSE) console.log(`  ok   ${label}`);
		return true;
	}
	failures += 1;
	console.error(`  FAIL ${label}${detail ? ` — ${detail}` : ""}`);
	return false;
}

const read = (path) => readFileSync(path, "utf8");

/* ── Files ---------------------------------------------------------- */

const html = read(join(DOCS, "index.html"));
const css = read(join(DOCS, "assets/css/vantage.css"));
const scripts = {
	vantage: read(join(DOCS, "assets/js/vantage.js")),
	themes: read(join(DOCS, "assets/js/themes.js")),
	easing: read(join(DOCS, "assets/js/easing.js")),
	loading: read(join(DOCS, "assets/js/loading.js"))
};

console.log("docs: structure");

for (const [name, file] of Object.entries({
	"index.html": "index.html",
	"assets/css/vantage.css": "assets/css/vantage.css",
	"assets/js/vantage.js": "assets/js/vantage.js",
	"assets/js/themes.js": "assets/js/themes.js",
	"assets/js/easing.js": "assets/js/easing.js",
	"assets/js/loading.js": "assets/js/loading.js",
	"assets/img/vantage-logo.png": "assets/img/vantage-logo.png",
	"TUTORIAL.md": "TUTORIAL.md"
})) {
	check(`docs/${file} exists`, existsSync(join(DOCS, file)));
}

/* ── Local references resolve --------------------------------------- */

console.log("docs: references");

const localRefs = new Set();
for (const match of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
	const target = match[1];
	if (/^(https?:|mailto:|#|data:)/.test(target)) continue;
	localRefs.add(target);
}
for (const ref of localRefs) {
	const path = join(DOCS, ref.split(/[?#]/)[0]);
	check(`reference resolves: ${ref}`, existsSync(path));
}

// Anchors the page links to must exist, or the nav is lying.
for (const match of html.matchAll(/href="#([^"]+)"/g)) {
	const id = match[1];
	check(`anchor target exists: #${id}`, new RegExp(`id="${id}"`).test(html));
}

// The stylesheet's logo token must point at a real file.
const logoToken = css.match(/--logo:\s*url\("([^"]+)"\)/);
check("css --logo token present", Boolean(logoToken));
if (logoToken) {
	check(`--logo target resolves: ${logoToken[1]}`, existsSync(join(DOCS, "assets/css", logoToken[1])));
}

/* ── The behavioural contract --------------------------------------- */

console.log("docs: hooks");

// Each of these is a hook a script looks up at boot. If one disappears, the
// component silently stops working — which is exactly the failure mode this
// check exists to catch.
// A hook is written as an attribute in the page and read as `[data-x]` in a
// script, so the check has to compare the attribute name — with a boundary, so
// that `data-replay` does not match a `data-replay-moved` typo.
const hasHook = (selector) => {
	const attribute = selector.replace(/^\[|\]$/g, "");
	return new RegExp(`${attribute}(?=[\\s=/>])`).test(html);
};

const REQUIRED_HOOKS = [
	// chrome
	"[data-theme-select]", "[data-theme-grid]", "[data-ease-grid]",
	"[data-toasts]", "[data-tooltip]", "[data-fps]", "[data-ping]", "[data-mem]",
	// loading screen
	"[data-loading-stage]", "[data-wave]", "[data-bar]", "[data-percent]",
	"[data-phase]", "[data-detail]", "[data-tip-text]", "[data-continue]",
	"[data-autocontinue]", "[data-replay]", "[data-loading-control]",
	// playground
	"[data-progress-fill]", "[data-progress-run]", "[data-progress-reset]",
	"[data-progress-readout]", "[data-motion-box]", "[data-motion-easing]",
	"[data-motion-play]", "[data-motion-elastic]", "[data-motion-duration]",
	"[data-open-palette]", "[data-tip]", "[data-toast]", "[data-toast-group]",
	"[data-toast-actions]", "[data-modal]"
];
for (const hook of REQUIRED_HOOKS) {
	check(`hook present: ${hook}`, hasHook(hook));
}

// The scripts must not look up a static hook that the page never provides.
// Selectors for nodes a script creates itself are exempt, and so is any hook
// that appears in more than one script (the shared readout pattern, say).
const DYNAMIC_HOOKS = new Set([
	// Created by a script rather than authored in the page.
	"[data-count]", "[data-chord]", "[data-label]", "[data-readout]",
	"[data-index]", "[data-out]", "[data-value]", "[data-band]",
	"[data-theme-card]", "[data-cancel]", "[data-confirm]"
]);
for (const [file, source] of Object.entries(scripts)) {
	for (const match of source.matchAll(/querySelector(?:All)?\(\s*"(\[[a-z-]+\])"/g)) {
		const selector = match[1];
		if (!selector.startsWith("[data-") || DYNAMIC_HOOKS.has(selector)) continue;
		check(`${file}.js looks up ${selector} — the page must render it`, hasHook(selector));
	}
}

/* ── Tabs and panels are paired ------------------------------------- */

const tabs = [...html.matchAll(/data-tab="([^"]+)"/g)].map((m) => m[1]);
const panels = [...html.matchAll(/data-panel="([^"]+)"/g)].map((m) => m[1]);
check(`every tab has a panel (${tabs.length} tabs)`, tabs.every((name) => panels.includes(name)));
check(`every panel has a tab (${panels.length} panels)`, panels.every((name) => tabs.includes(name)));
check("exactly one panel starts active", (html.match(/class="panel active"/g) ?? []).length === 1);

/* ── Copy buttons point at real elements ---------------------------- */

for (const match of html.matchAll(/data-copy="#([^"]+)"/g)) {
	check(`copy target exists: ${match[1]}`, new RegExp(`id="${match[1]}"`).test(html));
}
check("copy buttons exist", (html.match(/data-copy=/g) ?? []).length >= 5);

/* ── Tooltips carry the title|body shape the script parses ---------- */

for (const match of html.matchAll(/data-tip="([^"]*)"/g)) {
	check(`tooltip has a separator: ${match[1].slice(0, 24)}…`, match[1].includes("|"));
}

/* ── Dropdown options carry a clean value --------------------------- */

const options = [...html.matchAll(/<div class="option"[^>]*>/g)].map((m) => m[0]);
check("dropdown options exist", options.length >= 5);
for (const option of options) {
	check("option sets data-value", /data-value="[^"]+"/.test(option), option.slice(0, 60));
	check("option sets aria-selected", /aria-selected="(true|false)"/.test(option));
}

/* ── Loading controls have readouts --------------------------------- */

const controls = [...html.matchAll(/data-loading-control="([^"]+)"/g)].map((m) => m[1]);
check("loading controls exist", controls.length === 4);
for (const name of controls) {
	check(`loading control has a readout: ${name}`, html.includes(`data-out="${name}"`));
}
const stageSlices = html.match(/data-loading-stage[^>]*data-slices="(\d+)"/);
const sliceControl = html.match(/<input[^>]*value="(\d+)"[^>]*data-loading-control="slices"/);
check("stage slice count matches its control", stageSlices && sliceControl && stageSlices[1] === sliceControl[1],
	`${stageSlices?.[1]} vs ${sliceControl?.[1]}`);

/* ── Labels are wired to their inputs ------------------------------- */

for (const match of html.matchAll(/<label for="([^"]+)"/g)) {
	check(`label target exists: ${match[1]}`, new RegExp(`id="${match[1]}"`).test(html));
}

/* ── The logo is never inside the recreated interface -------------- */

console.log("docs: brand rules");
const windowBlock = html.slice(html.indexOf('<div class="window">'), html.indexOf('<div class="statusbar">'));
check("no logo image inside the recreated window", !/vantage-logo\.png/.test(windowBlock));
const stageBlock = html.slice(html.indexOf('data-loading-stage'), html.indexOf("</section>", html.indexOf('data-loading-stage')));
check("the loading stage does render the mark", /data-wave/.test(stageBlock));
check("the mark is bottom-right in the stage", /class="logo-block"/.test(stageBlock));

/* ── The house theme is not blue ------------------------------------ */

console.log("docs: theme");
const obsidian = scripts.themes.slice(scripts.themes.indexOf('"name": "obsidian"'));
const accent = obsidian.match(/"accent":\s*"#([0-9A-Fa-f]{6})"/);
check("obsidian accent is present", Boolean(accent));
if (accent) {
	const [r, g, b] = [0, 2, 4].map((i) => parseInt(accent[1].slice(i, i + 2), 16));
	check(`obsidian accent is warm, not blue (#${accent[1]})`, r > b && r >= g,
		`r=${r} g=${g} b=${b}`);
}
check("ten themes are shipped", (scripts.themes.match(/"name":/g) ?? []).length === 10);
check("the page documents every theme", /data-theme-grid/.test(html));

/* ── Scripts parse -------------------------------------------------- */

console.log("docs: syntax");
const temp = mkdtempSync(join(tmpdir(), "vantage-docs-"));
try {
	for (const [name, source] of Object.entries(scripts)) {
		const file = join(temp, `${name}.mjs`);
		copyFileSync(join(DOCS, `assets/js/${name}.js`), file);
		try {
			execFileSync(process.execPath, ["--check", file], { stdio: "pipe" });
			check(`${name}.js parses as an ES module`, true);
		} catch (error) {
			check(`${name}.js parses as an ES module`, false, String(error.stderr ?? error).split("\n")[0]);
		}
	}
} finally {
	rmSync(temp, { recursive: true, force: true });
}

/* ── Result --------------------------------------------------------- */

if (failures === 0) {
	console.log(`docs: clean (${checks} checks)`);
	process.exit(0);
}
console.error(`docs: ${failures} of ${checks} checks failed`);
process.exit(1);
