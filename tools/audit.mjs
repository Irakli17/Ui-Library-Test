#!/usr/bin/env node
/**
 * Vantage · tools/audit.mjs
 * ------------------------------------------------------------------
 * Static checks for the failure modes the type checker cannot see.
 *
 * Both of the checks here exist because they caught real bugs:
 *
 *   1. Methods vs fields. A class method named `List` and an instance
 *      field named `List` are the same key on the same table, so the
 *      field silently replaces the method. `palette:List()` then throws
 *      "attempt to call a table value" the first time a user touches it,
 *      in a path no unit test happened to exercise. Same for
 *      `LoadingScreen:_complete` vs `self._complete = false`.
 *
 *   2. Motion presets. `Motion.options("fast")` falls back to the hover
 *      preset and warns. A library that warns about its own preset names
 *      is a library with a typo in it.
 *
 * Usage:
 *   node tools/audit.mjs
 */

import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, resolve, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(fileURLToPath(new URL("..", import.meta.url)));
const SRC = join(ROOT, "src");

function walk(dir) {
	const out = [];
	for (const entry of readdirSync(dir, { withFileTypes: true })) {
		const abs = join(dir, entry.name);
		if (entry.isDirectory()) out.push(...walk(abs));
		else if (entry.name.endsWith(".luau")) out.push(abs);
	}
	return out;
}

const files = walk(SRC).sort();
const problems = [];

/* 1 · method / field collisions ------------------------------------ */

const METHOD = /^function\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(/gm;
const CONSTRUCTOR = /setmetatable\(\{([\s\S]*?)\n\t\},/g;
const FIELD = /self\.([A-Za-z_][A-Za-z0-9_]*)\s*=/g;

for (const path of files) {
	const source = readFileSync(path, "utf8");
	const label = relative(ROOT, path).split(sep).join("/");

	const methods = new Map();
	for (const match of source.matchAll(METHOD)) {
		const [, klass, name] = match;
		if (!methods.has(klass)) methods.set(klass, new Map());
		methods.get(klass).set(name, source.slice(0, match.index).split("\n").length);
	}

	const fields = new Map();
	const noteField = (klass, name, index) => {
		if (!fields.has(klass)) fields.set(klass, new Map());
		if (!fields.get(klass).has(name)) {
			fields.get(klass).set(name, source.slice(0, index).split("\n").length);
		}
	};

	for (const match of source.matchAll(CONSTRUCTOR)) {
		// `setmetatable({ ... }, X)` — the literal's own keys belong to X.
		const after = source.slice(match.index + match[0].length);
		const klass = after.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)/);
		if (!klass) continue;
		for (const key of match[1].matchAll(/\n\t\t([A-Za-z_][A-Za-z0-9_]*)\s*=/g)) {
			noteField(klass[1], key[1], match.index + key.index);
		}
	}

	// One class per file is the norm here. With several, a `self.X = …`
	// line belongs to the nearest preceding method definition.
	const methodLines = [];
	for (const [klass, entries] of methods) {
		for (const line of entries.values()) methodLines.push({ klass, line });
	}
	methodLines.sort((a, b) => a.line - b.line);
	const onlyClass = methods.size === 1 ? [...methods.keys()][0] : null;

	for (const match of source.matchAll(FIELD)) {
		const line = source.slice(0, match.index).split("\n").length;
		let klass = onlyClass;
		if (!klass) {
			for (const entry of methodLines) {
				if (entry.line <= line) klass = entry.klass;
			}
		}
		noteField(klass ?? "*", match[1], match.index);
	}

	for (const [klass, classMethods] of methods) {
		const classFields = fields.get(klass);
		if (!classFields) continue;
		for (const [name, line] of classMethods) {
			if (classFields.has(name)) {
				problems.push(
					`${label}: ${klass} defines method \`:${name}\` (line ${line}) and also assigns ` +
						`\`self.${name}\` (line ${classFields.get(name)}) — the field wins at runtime.`
				);
			}
		}
	}
}

/* 2 · motion presets ----------------------------------------------- */

const motionPath = join(SRC, "Core", "Motion.luau");
const motion = readFileSync(motionPath, "utf8");
const presetBlock = motion.match(/Motion\.presets\s*=\s*\{([\s\S]*?)\n\}/);
if (!presetBlock) {
	problems.push("src/Core/Motion.luau: could not find Motion.presets.");
} else {
	const defined = new Set();
	for (const match of presetBlock[1].matchAll(/\n\t([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\{/g)) {
		defined.add(match[1]);
	}
	for (const path of files) {
		const source = readFileSync(path, "utf8");
		const label = relative(ROOT, path).split(sep).join("/");
		for (const match of source.matchAll(/Motion\.options\(\s*"([A-Za-z_][A-Za-z0-9_]*)"/g)) {
			if (!defined.has(match[1])) {
				const line = source.slice(0, match.index).split("\n").length;
				problems.push(
					`${label}: Motion.options("${match[1]}") (line ${line}) is not a preset — ` +
						`known: ${[...defined].sort().join(", ")}.`
				);
			}
		}
	}
}

/* 3 · glyph names referenced from source docs ---------------------- */

const glyphSource = readFileSync(join(SRC, "Core", "Glyph.luau"), "utf8");
const glyphNames = new Set();
for (const match of glyphSource.matchAll(/define\(\s*"([a-z0-9-]+)"/g)) glyphNames.add(match[1]);

if (glyphNames.size === 0) {
	problems.push("src/Core/Glyph.luau: could not read the glyph definitions.");
} else {
	// Every glyph name written literally in the library — `Glyph.draw(x, "search")`,
	// an `Icon = "…"` in a default spec — has to exist, or the interface ships
	// with a warning and an empty box where an icon should be.
	const LITERAL = /(?:Glyph\.(?:draw|create)\([^,]+,\s*|Icon\s*=\s*)"([a-z0-9-]+)"/g;
	for (const path of files) {
		const source = readFileSync(path, "utf8");
		const label = relative(ROOT, path).split(sep).join("/");
		for (const match of source.matchAll(LITERAL)) {
			if (!glyphNames.has(match[1])) {
				const line = source.slice(0, match.index).split("\n").length;
				problems.push(`${label}: glyph "${match[1]}" (line ${line}) is not defined in Glyph.`);
			}
		}
	}
}

/* Report ----------------------------------------------------------- */

if (problems.length > 0) {
	console.error(`audit: ${problems.length} problem(s)\n`);
	for (const problem of problems) console.error(`  · ${problem}`);
	process.exit(1);
}

console.log(
	`audit: clean (${files.length} modules, ${glyphNames.size || "?"} glyphs, method/field and preset checks passed).`
);
