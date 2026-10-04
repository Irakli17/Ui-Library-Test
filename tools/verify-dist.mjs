#!/usr/bin/env node
/**
 * Vantage · tools/verify-dist.mjs
 * ------------------------------------------------------------------
 * Proves the *shipped* file works the way users actually load it.
 *
 * `node tools/test.mjs` runs the source tree through a bundler and a
 * headless mock. That is a strong signal, but it does not answer the
 * question that matters most for a loadstring distribution:
 *
 *     If I point loadstring at this GitHub file, does it run?
 *
 * So this script does exactly that, and nothing softer:
 *
 *   1. Boots the mock Roblox runtime.
 *   2. Deletes the `script` global — an executor has no such global, and
 *      a bundle that touches it would break there while passing every
 *      Rojo-based test.
 *   3. Reads dist/Vantage.luau (and dist/Vantage.min.luau) from disk.
 *   4. Hands the bytes to `loadstring`, the way a loader script does.
 *   5. Runs tests/Integration.luau against the returned namespace.
 *
 * The bundle is embedded as a long string with a delimiter level computed
 * from its own contents, so no amount of brackets in the source can break
 * out of it.
 *
 * Usage:
 *   node tools/verify-dist.mjs            # both artifacts
 *   node tools/verify-dist.mjs --min      # the minified build only
 *   node tools/verify-dist.mjs --full     # the annotated build only
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { buildIntegrationRun } from "./lib/integration-harness.mjs";

const ROOT = resolve(fileURLToPath(new URL("..", import.meta.url)));
const BUILD = join(ROOT, "tests", "build");

const LUAU_CANDIDATES = [join(ROOT, ".tools", "luau", "luau.exe"), join(ROOT, ".tools", "luau", "luau")];
const LUAU = LUAU_CANDIDATES.find((path) => existsSync(path)) ?? "luau";

const flags = process.argv.slice(2);
const MIN_ONLY = flags.includes("--min");
const FULL_ONLY = flags.includes("--full");

const artifacts = [
	{ label: "dist/Vantage.luau", file: "Vantage.luau", enabled: !MIN_ONLY },
	{ label: "dist/Vantage.min.luau", file: "Vantage.min.luau", enabled: !FULL_ONLY },
].filter((entry) => entry.enabled);

if (artifacts.length === 0) {
	console.error("verify-dist: pick one of --min or --full, not both.");
	process.exit(1);
}

function read(...parts) {
	return readFileSync(join(ROOT, ...parts), "utf8");
}

mkdirSync(BUILD, { recursive: true });

let failures = 0;

for (const artifact of artifacts) {
	const source = read("dist", artifact.file);
	const out = join(BUILD, `integration-${artifact.file.replace(/\.luau$/, "")}.luau`);
	writeFileSync(out, buildIntegrationRun(ROOT, source, artifact.label));

	const result = spawnSync(LUAU, ["-O2", out], { cwd: ROOT, encoding: "utf8" });

	if (result.error) {
		console.error(`verify-dist: could not launch ${LUAU}: ${result.error.message}`);
		console.error("verify-dist: run tools/install-toolchain.sh to fetch the Luau CLI.");
		process.exit(2);
	}

	process.stdout.write(result.stdout ?? "");
	process.stderr.write(result.stderr ?? "");

	const marker = (result.stdout ?? "").match(/RESULT fail=(\d+)/);
	if (!marker) {
		console.error(`verify-dist: ${artifact.label} never reached its result line.`);
		failures += 1;
	} else if (marker[1] !== "0") {
		failures += 1;
	}
}

if (failures > 0) {
	console.error(`verify-dist: ${failures} artifact(s) failed.`);
	process.exit(1);
}

console.log(`verify-dist: ${artifacts.length} artifact(s) run from loadstring without a script global.`);
