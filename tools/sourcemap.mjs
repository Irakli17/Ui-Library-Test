#!/usr/bin/env node
/**
 * Vantage · tools/sourcemap.mjs
 * ------------------------------------------------------------------
 * Generates a Rojo-compatible `sourcemap.json` from the on-disk tree.
 *
 * Static analysers resolve `require(script.Parent.Foo)` by walking a
 * sourcemap rather than the filesystem, so without this file
 * `luau-lsp analyze` reports a wall of phantom "Key not found in
 * external type 'Instance'" errors on every cross-module require.
 *
 * The file is generated, never hand-edited, and is written to both the
 * repository root (for editors) and `.vantage/` (for CI).
 *
 *   node tools/sourcemap.mjs
 */

import { readdirSync, statSync, writeFileSync, mkdirSync } from "node:fs";
import { join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

// Native resolution: `relative` and `join` must agree on separators or
// Windows hosts end up with doubled paths.
const ROOT = resolve(fileURLToPath(new URL("..", import.meta.url)));

/** Where the DataModel tree starts and what the root is called. */
const PROJECTS = [
	{ path: "src", name: "Vantage", className: "ModuleScript" },
	{ path: "tests", name: "VantageTests", className: "Folder" },
];

function classify(file) {
	if (file.endsWith(".luau") || file.endsWith(".lua")) return "ModuleScript";
	if (file.endsWith(".json")) return "ModuleScript";
	if (file.endsWith(".rbxm") || file.endsWith(".rbxmx")) return "Model";
	return "ModuleScript";
}

/** Recursively builds a node for `dir`, mirroring Rojo's `init.luau` rule. */
function buildNode(absDir, name, filePaths) {
	const node = { name, className: "Folder", children: [] };
	const initFile = ["init.luau", "init.lua"].map((f) => join(absDir, f)).find(isFile);
	if (initFile) {
		node.className = classify(initFile);
		node.filePaths = [rel(initFile)];
	}

	const entries = readdirSync(absDir, { withFileTypes: true }).sort((a, b) =>
		a.name.localeCompare(b.name)
	);

	for (const entry of entries) {
		const abs = join(absDir, entry.name);
		if (entry.isDirectory()) {
			if (entry.name.startsWith(".") || entry.name === "node_modules") continue;
			// A directory only becomes a node when it contains scripts.
			if (!containsScripts(abs)) continue;
			node.children.push(buildNode(abs, entry.name, filePaths));
			continue;
		}
		const base = entry.name.replace(/\.(luau|lua)$/, "");
		if (base === "init") continue;
		if (!/\.(luau|lua)$/.test(entry.name)) continue;
		node.children.push({
			name: base,
			className: classify(entry.name),
			filePaths: [rel(abs)],
		});
	}

	if (node.children.length === 0) delete node.children;
	return node;
}

function containsScripts(dir) {
	for (const entry of readdirSync(dir, { withFileTypes: true })) {
		if (entry.isDirectory()) {
			if (entry.name.startsWith(".") || entry.name === "node_modules") continue;
			if (containsScripts(join(dir, entry.name))) return true;
		} else if (/\.(luau|lua)$/.test(entry.name)) {
			return true;
		}
	}
	return false;
}

function exists(path) {
	try {
		statSync(path);
		return true;
	} catch {
		return false;
	}
}

function isFile(path) {
	try {
		return statSync(path).isFile();
	} catch {
		return false;
	}
}

function rel(abs) {
	return relative(ROOT, abs).split(sep).join("/");
}

const sourcemap = {
	name: "Vantage",
	className: "DataModel",
	children: PROJECTS.filter((project) => exists(join(ROOT, project.path))).map((project) =>
		buildNode(join(ROOT, project.path), project.name, [])
	),
};

const json = JSON.stringify(sourcemap, null, 2);

writeFileSync(join(ROOT, "sourcemap.json"), json + "\n");
mkdirSync(join(ROOT, ".vantage"), { recursive: true });
writeFileSync(join(ROOT, ".vantage", "sourcemap.json"), json + "\n");

function count(node) {
	let total = 1;
	for (const child of node.children ?? []) total += count(child);
	return total;
}

const total = sourcemap.children.reduce((sum, node) => sum + count(node), 0);
console.log(`sourcemap.json written — ${total} nodes`);
