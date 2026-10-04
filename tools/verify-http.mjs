#!/usr/bin/env node
/**
 * Vantage · tools/verify-http.mjs
 * ------------------------------------------------------------------
 * The loadstring path, end to end, without GitHub in the middle.
 *
 *     loadstring(game:HttpGet("https://raw.githubusercontent.com/…/Vantage.luau"))()
 *
 * Three things can go wrong on that line and only one of them is Luau:
 *
 *   1. the file is not in the repository at that path on that branch,
 *   2. the server does not hand back the bytes verbatim (encoding, line
 *      endings, a stray BOM),
 *   3. the bytes do not compile or do not return the namespace.
 *
 * This script reproduces 2 and 3 locally, and `tools/repo-audit.mjs` covers
 * 1. A static server is started that serves the repository exactly the way
 * raw.githubusercontent.com does — `Content-Type: text/plain`, no
 * transformation — the file is fetched over real HTTP, compared
 * byte-for-byte with what is on disk, and *those fetched bytes* are handed
 * to `loadstring` inside the mock Roblox runtime with no `script` global.
 *
 * Usage:
 *   node tools/verify-http.mjs            # every published artifact
 *   node tools/verify-http.mjs --verbose  # log each request
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync, statSync } from "node:fs";
import { join, resolve, extname } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { createServer } from "node:http";
import { buildIntegrationRun } from "./lib/integration-harness.mjs";

const ROOT = resolve(fileURLToPath(new URL("..", import.meta.url)));
const BUILD = join(ROOT, "tests", "build");
const VERBOSE = process.argv.includes("--verbose");

const LUAU = [join(ROOT, ".tools", "luau", "luau.exe"), join(ROOT, ".tools", "luau", "luau")].find((path) => existsSync(path)) ?? "luau";

/**
 * The published artifacts, in the order a user is likely to meet them. The
 * root copy exists because the URL stays short, and it is the same bytes as
 * `dist/Vantage.luau` — asserted below, not assumed.
 */
const ARTIFACTS = [
	{ path: "/Vantage.luau", of: "Vantage.luau", note: "root copy — the short URL people paste" },
	{ path: "/Vantage.lua", of: "Vantage.lua", note: "same bytes under the .lua name loaders expect" },
	{ path: "/dist/Vantage.luau", of: "dist/Vantage.luau", note: "canonical annotated build" },
	{ path: "/dist/Vantage.min.luau", of: "dist/Vantage.min.luau", note: "minified build" }
];

const CONTENT_TYPES = {
	".luau": "text/plain; charset=utf-8",
	".lua": "text/plain; charset=utf-8",
	".md": "text/plain; charset=utf-8",
	".json": "application/json",
	".png": "image/png"
};

mkdirSync(BUILD, { recursive: true });

const server = createServer((request, response) => {
	const url = new URL(request.url ?? "/", "http://localhost");
	// Mirrors raw.githubusercontent.com: no compression, no rewrites, no
	// headers beyond a content type and a length.
	const target = join(ROOT, decodeURIComponent(url.pathname));
	if (!target.startsWith(ROOT) || !existsSync(target) || !statSync(target).isFile()) {
		response.writeHead(404, { "content-type": "text/plain" });
		response.end("404: Not Found");
		return;
	}
	const body = readFileSync(target);
	if (VERBOSE) console.log(`  served ${url.pathname} (${body.length} bytes)`);
	response.writeHead(200, {
		"content-type": CONTENT_TYPES[extname(target).toLowerCase()] ?? "application/octet-stream",
		"content-length": body.length,
		"cache-control": "no-store"
	});
	response.end(body);
});

await new Promise((ready) => server.listen(0, "127.0.0.1", ready));
const origin = `http://127.0.0.1:${server.address().port}`;
console.log(`verify-http: serving ${ROOT} at ${origin}\n`);

let failures = 0;

try {
	for (const artifact of ARTIFACTS) {
		const local = readFileSync(join(ROOT, artifact.of));
		const response = await fetch(origin + artifact.path);
		const served = Buffer.from(await response.arrayBuffer());

		console.log(`${artifact.path}  ·  ${artifact.note}`);
		console.log(`  content-type: ${response.headers.get("content-type")}`);
		console.log(`  bytes: ${served.length}`);

		if (response.status !== 200) {
			console.error(`  FAIL status ${response.status}`);
			failures += 1;
			continue;
		}

		// 1. The bytes over the wire are the bytes on disk.
		if (!local.equals(served)) {
			console.error(`  FAIL the served bytes differ from ${artifact.of} (${local.length} vs ${served.length})`);
			failures += 1;
			continue;
		}
		console.log("  ok   served bytes are identical to the file on disk");

		// 2. No BOM, no CRLF, no hidden prefix — the three things that make
		//    a file that compiles locally fail when served.
		const head = served.subarray(0, 3);
		const bom = head[0] === 0xef && head[1] === 0xbb && head[2] === 0xbf;
		const crlf = served.includes(Buffer.from([0x0d, 0x0a]));
		const firstLine = served.toString("utf8", 0, Math.min(served.length, 120)).split("\n")[0];
		const shebang = firstLine.startsWith("#!");
		console.log(`  ${bom ? "FAIL" : "ok  "} no UTF-8 BOM`);
		console.log(`  ${crlf ? "FAIL" : "ok  "} LF line endings`);
		console.log(`  ${shebang ? "FAIL" : "ok  "} no shebang (Luau would not parse one)`);
		if (VERBOSE) console.log(`  first line: ${firstLine.slice(0, 72)}`);
		if (bom || crlf || shebang) failures += 1;

		// 3. The fetched text compiles and returns the namespace.
		const label = `http://127.0.0.1/…${artifact.path}`;
		const run = join(BUILD, `http-${artifact.of.replace(/[\\/]/g, "-").replace(/\.luau$/, "")}.luau`);
		writeFileSync(run, buildIntegrationRun(ROOT, served.toString("utf8"), label));

		const result = spawnSync(LUAU, ["-O2", run], { cwd: ROOT, encoding: "utf8" });
		if (result.error) {
			console.error(`  FAIL could not launch the Luau CLI: ${result.error.message}`);
			console.error("  run tools/install-toolchain.sh to fetch it");
			failures += 1;
			continue;
		}

		const output = result.stdout ?? "";
		const marker = output.match(/RESULT fail=(\d+)/);
		const assertions = output.match(/(\d+)\/(\d+) assertions passed/);

		if (!marker) {
			process.stdout.write(output);
			console.error("  FAIL the fetched bundle never reached its result line");
			failures += 1;
			continue;
		}
		if (marker[1] !== "0") {
			process.stdout.write(output);
			console.error(`  FAIL ${marker[1]} integration assertion(s) failed on the served bytes`);
			failures += 1;
			continue;
		}
		console.log(`  ok   loadstring ran the served bytes${assertions ? ` (${assertions[1]} assertions)` : ""}`);
		console.log("");
	}
} finally {
	server.close();
}

if (failures > 0) {
	console.error(`verify-http: ${failures} check(s) failed.`);
	process.exit(1);
}

console.log(`verify-http: ${ARTIFACTS.length} artifact(s) verified as served over HTTP and loadstring'd.`);
