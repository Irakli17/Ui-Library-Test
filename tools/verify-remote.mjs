#!/usr/bin/env node
/**
 * Vantage · tools/verify-remote.mjs
 * ------------------------------------------------------------------
 * Checks what the world actually downloads from the URLs the README and
 * the tutorial tell people to paste into an executor.
 *
 * The local suite proves the artifact in this checkout is correct; it
 * cannot prove the *published* one is, and the two drift the moment a
 * fix is committed without the rebuilt file being uploaded. That drift
 * is not a hypothetical: the build that threw
 * `ColorSequence.new(): expected 'ColorSequenceKeypoint' at index 1` on
 * a live client stayed on GitHub while a fixed bundle sat in the
 * working tree, so the loadstring every player tried kept failing.
 *
 * Usage:
 *   node tools/verify-remote.mjs            # check every published URL
 *   node tools/verify-remote.mjs --quiet     # one summary line
 *
 * Exit code is the number of stale or missing artifacts, so CI can gate
 * on "the repository serves what the tests passed".
 */

import { createHash } from "node:crypto";
import { readFileSync, existsSync } from "node:fs";
import { join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(fileURLToPath(new URL("..", import.meta.url)));
const QUIET = process.argv.includes("--quiet");

const REPO = process.env.VANTAGE_REPO ?? "Irakli17/Ui-Library-Test";
const BRANCH = process.env.VANTAGE_BRANCH ?? "main";

/** Each published artifact: the URL people use, and the file it should be. */
const ARTIFACTS = [
	{
		url: `https://raw.githubusercontent.com/${REPO}/${BRANCH}/Vantage.luau`,
		file: "Vantage.luau",
		loads: 'loadstring(game:HttpGet("…/Vantage.luau"))()',
	},
	{
		url: `https://raw.githubusercontent.com/${REPO}/${BRANCH}/Vantage.lua`,
		file: "Vantage.lua",
		loads: 'loadstring(game:HttpGet("…/Vantage.lua"))()',
	},
	{
		url: `https://raw.githubusercontent.com/${REPO}/${BRANCH}/dist/Vantage.luau`,
		file: "dist/Vantage.luau",
		loads: 'loadstring(game:HttpGet("…/dist/Vantage.luau"))()',
	},
	{
		url: `https://raw.githubusercontent.com/${REPO}/${BRANCH}/dist/Vantage.min.luau`,
		file: "dist/Vantage.min.luau",
		loads: 'loadstring(game:HttpGet("…/dist/Vantage.min.luau"))()',
	},
	{
		url: `https://cdn.jsdelivr.net/gh/${REPO}@${BRANCH}/Vantage.luau`,
		file: "Vantage.luau",
		loads: 'loadstring(game:HttpGet("cdn.jsdelivr.net/gh/…/Vantage.luau"))()',
	},
];

const digest = (buffer) => createHash("sha256").update(buffer).digest("hex");
const short = (hash) => hash.slice(0, 12);

async function fetchBytes(url) {
	try {
		const response = await fetch(url, { redirect: "follow" });
		if (!response.ok) return { error: `HTTP ${response.status}` };
		const body = Buffer.from(await response.arrayBuffer());
		return { body };
	} catch (error) {
		return { error: error.message };
	}
}

const rows = [];
let stale = 0;

for (const artifact of ARTIFACTS) {
	const path = join(ROOT, artifact.file);
	if (!existsSync(path)) {
		rows.push({ artifact, status: "MISSING LOCALLY", detail: "run node tools/bundle.mjs" });
		stale += 1;
		continue;
	}

	const local = readFileSync(path);
	const localHash = digest(local);
	const remote = await fetchBytes(artifact.url);

	if (remote.error) {
		rows.push({ artifact, status: "NOT PUBLISHED", detail: remote.error });
		stale += 1;
		continue;
	}

	const remoteHash = digest(remote.body);
	if (remoteHash === localHash) {
		rows.push({ artifact, status: "up to date", detail: `${local.length} bytes · ${short(localHash)}` });
	} else {
		// A stale file is the dangerous case: the URL works, so it looks fine,
		// and it serves a build the suite has already moved past.
		rows.push({
			artifact,
			status: "STALE",
			detail: `serves ${remote.body.length} bytes (${short(remoteHash)}), local is ${local.length} bytes (${short(localHash)})`,
		});
		stale += 1;
	}
}

if (!QUIET) {
	console.log(`\nVantage · published artifacts (${REPO}@${BRANCH})\n`);
	for (const row of rows) {
		const mark = row.status === "up to date" ? "ok  " : "FAIL";
		console.log(`  ${mark} ${row.status.padEnd(16)} ${row.artifact.file}`);
		console.log(`       ${row.artifact.url}`);
		console.log(`       ${row.detail}\n`);
	}
}

if (stale === 0) {
	console.log(`verify-remote: all ${rows.length} published URL(s) match this checkout.`);
} else {
	console.log(
		`verify-remote: ${stale} of ${rows.length} published URL(s) are stale or missing. ` +
			"Upload the files above (the URLs are already correct — only their contents need refreshing)."
	);
}

process.exit(stale === 0 ? 0 : 1);
