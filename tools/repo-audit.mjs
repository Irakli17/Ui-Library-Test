#!/usr/bin/env node
/**
 * Vantage · tools/repo-audit.mjs
 * ------------------------------------------------------------------
 * "Is this repository uploadable as it stands, and will the loadstring
 * URL work once it is up?"
 *
 * That question has a few concrete answers, so this checks them instead
 * of guessing:
 *
 *   · Every file that would be committed is under GitHub's limits
 *     (100 MB hard, 50 MB warning), and the working tree is small.
 *   · The artifacts the documented URLs point at exist, are non-empty,
 *     and are committed — not git-ignored. A raw URL to an ignored file
 *     is a 404 for every user.
 *   · The files a public repository needs (README, LICENSE, CI, tutorial)
 *     are present.
 *   · The bundles are self-contained: no `script` dereference anywhere in
 *     the code, which is what makes a loadstring work at all.
 *
 * Usage:
 *   node tools/repo-audit.mjs
 */

import { readdirSync, readFileSync, statSync, existsSync } from "node:fs";
import { join, resolve, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(fileURLToPath(new URL("..", import.meta.url)));

// Paths that will not be committed: local toolchain, generated test builds,
// editor and system noise. Mirrors .gitignore.
const IGNORED = [/^\.tools\//, /^tests\/build\//, /^node_modules\//, /^\.git\//, /^\.freebuff\//, /(^|\/)\.DS_Store$/, /(^|\/)Thumbs\.db$/];

const LIMIT_HARD = 100 * 1024 * 1024;
const LIMIT_WARN = 50 * 1024 * 1024;
const TREE_WARN = 25 * 1024 * 1024;

const problems = [];
const warnings = [];

/**
 * Returns the code of a Luau file with line comments, long comments and
 * string bodies removed — the same view tools/bundle.mjs uses for its
 * `script` guard, so this tool cannot disagree with the build.
 */
function codeOnly(source) {
	let out = "";
	let longLevel = -1;

	for (const line of source.split("\n")) {
		let i = 0;
		while (i < line.length) {
			if (longLevel >= 0) {
				const closer = "]" + "=".repeat(longLevel) + "]";
				const end = line.indexOf(closer, i);
				if (end === -1) {
					i = line.length;
					break;
				}
				longLevel = -1;
				i = end + closer.length;
				continue;
			}

			if (line.startsWith("--", i)) {
				const open = line.slice(i).match(/^--\[(=*)\[/);
				if (open) {
					longLevel = open[1].length;
					i += open[0].length;
					continue;
				}
				break; // line comment: nothing after it is code
			}

			const ch = line[i];
			if (ch === '"' || ch === "'") {
				i += 1;
				while (i < line.length) {
					if (line[i] === "\\") {
						i += 2;
						continue;
					}
					if (line[i] === ch) {
						i += 1;
						break;
					}
					i += 1;
				}
				out += '""';
				continue;
			}

			out += ch;
			i += 1;
		}
		out += "\n";
	}
	return out;
}

function tracked(relativePath) {
	return !IGNORED.some((pattern) => pattern.test(relativePath));
}

function walk(dir, out = []) {
	for (const entry of readdirSync(dir, { withFileTypes: true })) {
		const abs = join(dir, entry.name);
		const rel = relative(ROOT, abs).split(sep).join("/");
		if (!tracked(rel)) continue;
		if (entry.isDirectory()) walk(abs, out);
		else out.push({ path: rel, bytes: statSync(abs).size });
	}
	return out;
}

const files = walk(ROOT).sort((a, b) => b.bytes - a.bytes);
const total = files.reduce((sum, file) => sum + file.bytes, 0);

for (const file of files) {
	if (file.bytes >= LIMIT_HARD) {
		problems.push(`${file.path} is ${(file.bytes / 1048576).toFixed(1)} MB — over GitHub's 100 MB hard limit.`);
	} else if (file.bytes >= LIMIT_WARN) {
		warnings.push(`${file.path} is ${(file.bytes / 1048576).toFixed(1)} MB — GitHub will warn above 50 MB.`);
	}
}

if (total > TREE_WARN) {
	warnings.push(`the working tree is ${(total / 1048576).toFixed(1)} MB, which is large for a source repository.`);
}

/* The artifacts the documented URLs point at ----------------------- */

const artifacts = [
	// Path · why it has to exist
	["Vantage.luau", "the short loadstring URL at the repository root"],
	["dist/Vantage.luau", "the canonical annotated artifact"],
	["dist/Vantage.min.luau", "the minified artifact"],
];

for (const [path, reason] of artifacts) {
	const abs = join(ROOT, path);
	if (!existsSync(abs)) {
		problems.push(`${path} does not exist — ${reason}.`);
		continue;
	}
	if (!tracked(path)) {
		problems.push(`${path} is git-ignored, so its raw URL would 404 — ${reason}.`);
		continue;
	}
	const size = statSync(abs).size;
	if (size === 0) problems.push(`${path} is empty — ${reason}.`);

	// A file that dereferences `script` cannot be run from loadstring. The
	// scan strips comments and string bodies first, so a doc comment that
	// mentions the word is not mistaken for a dependency on it.
	const code = codeOnly(readFileSync(abs, "utf8"));
	const match = code.match(/\bscript\b/);
	if (match) {
		const line = code.slice(0, match.index).split("\n").pop().trim().slice(0, 80);
		problems.push(`${path} dereferences \`script\` (${line}) — a loadstring would break.`);
	}
}

/* Repository hygiene ------------------------------------------------ */

const required = [
	["README.md", "GitHub shows it on the project page"],
	["LICENSE", "a public repository should state its terms"],
	["docs/TUTORIAL.md", "the quick-start walkthrough"],
	[".gitignore", "keeps the toolchain and generated builds out"],
	[".gitattributes", "keeps line endings consistent for everyone"],
	[".github/workflows/ci.yml", "runs the gates on every push"],
	["default.project.json", "Rojo needs it to serve the project"],
	["package.json", "wraps the verification commands"],
	["examples/loadstring.luau", "the one-file install example"],
];

for (const [path, why] of required) {
	if (!existsSync(join(ROOT, path))) problems.push(`${path} is missing — ${why}.`);
}

/* Report ------------------------------------------------------------ */

const kb = (bytes) => `${(bytes / 1024).toFixed(1)} KB`;

console.log(`repo-audit: ${files.length} files, ${kb(total)} total (uploadable)`);
console.log("  largest:");
for (const file of files.slice(0, 6)) console.log(`    ${file.path.padEnd(28)} ${kb(file.bytes)}`);

if (warnings.length > 0) {
	console.log("\n  warnings:");
	for (const warning of warnings) console.log(`    · ${warning}`);
}

if (problems.length > 0) {
	console.error(`\nrepo-audit: ${problems.length} blocker(s)`);
	for (const problem of problems) console.error(`  · ${problem}`);
	process.exit(1);
}

console.log("repo-audit: no blockers — the loadstring URLs resolve and no `script` dereference is shipped.");
