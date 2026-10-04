/**
 * Vantage · tools/lib/integration-harness.mjs
 * ------------------------------------------------------------------
 * Builds the file that takes a *shipped* bundle, hands it to `loadstring`
 * with no `script` global in scope, and runs the integration spec against
 * whatever comes back.
 *
 * It lives here rather than inside one tool because two of them need it and
 * they must agree exactly: `tools/verify-dist.mjs` (the artifact on disk) and
 * `tools/verify-http.mjs` (the same artifact fetched over HTTP, the way a
 * loader script gets it from GitHub).
 */

import { readFileSync } from "node:fs";
import { join } from "node:path";

/**
 * A Luau long-string level the given source cannot terminate early. Long
 * strings are `[[ … ]]` with any number of `=` between the brackets, so the
 * level is chosen from the source's own contents.
 */
export function safeLevel(source) {
	let level = 1;
	for (;;) {
		const closer = "]" + "=".repeat(level) + "]";
		if (!source.includes(closer)) return level;
		level += 1;
	}
}

/**
 * @param {string} root Repository root.
 * @param {string} source The exact bytes a user would load.
 * @param {string} label Human-readable origin, used in messages and the chunk name.
 * @returns {string} A runnable Luau file.
 */
export function buildIntegrationRun(root, source, label) {
	const read = (...parts) => readFileSync(join(root, ...parts), "utf8");
	const prelude = read("tests", "Mock", "prelude.luau");
	const harness = read("tests", "Harness.luau");
	const spec = read("tests", "Integration.luau");

	const level = safeLevel(source);
	const opener = "[" + "=".repeat(level) + "[";
	const closer = "]" + "=".repeat(level) + "]";

	const parts = [
		`-- GENERATED FILE — do not edit. Built by tools/lib/integration-harness.mjs for ${label}.`,
		"",
		"-- ── mock Roblox runtime ─────────────────────────────────────────────",
		prelude,
		"",
		"-- ── an executor has no `script` global ──────────────────────────────",
		"-- The prelude defines one so the module tree can be resolved during",
		"-- unit tests; here it is deleted on purpose. Anything the bundle does",
		"-- with `script` would now fail loudly, exactly as it would in-game.",
		"script = nil",
		'assert(script == nil, "integration harness: the script global must be nil")',
		"",
		"-- ── harness ─────────────────────────────────────────────────────────",
		"local Harness = (function()",
		harness,
		"end)()",
		"",
		"-- ── the shipped bytes, handed to loadstring ─────────────────────────",
		`local SOURCE = ${opener}`,
		source,
		`${closer}`,
		`local chunk, compileError = loadstring(SOURCE, "@${label}")`,
		"if not chunk then",
		`\terror("loadstring could not compile ${label}: " .. tostring(compileError))`,
		"end",
		"",
		"local Vantage = chunk()",
		'if type(Vantage) ~= "table" then',
		'\terror("loadstring returned " .. type(Vantage) .. ", expected the Vantage namespace")',
		"end",
		"",
		"-- Hand the animation scheduler to the mock so Mock.advance drives the",
		"-- same virtual clock the library animates on.",
		"Mock.motion = Vantage.Motion",
		"",
		"-- ── integration spec ────────────────────────────────────────────────",
		spec.trimEnd(),
		"",
		"-- ── report ──────────────────────────────────────────────────────────",
		`print(string.format("\\n\\27[1mVantage %s · loadstring integration%s\\27[0m\\n\\n", Vantage.version, " · ${label}"))`,
		'local failed = Harness.report("dist")',
		// The Luau CLI has no `os.exit`, and an exit code is a weak signal
		// anyway: the run prints a machine-readable result line that the
		// caller requires before it will call the artifact verified.
		'print(string.format("RESULT fail=%d", failed))',
		"if failed > 0 then",
		'\terror(string.format("%d integration assertion(s) failed", failed), 0)',
		"end",
		"return 0",
		"",
	];

	return parts.join("\n");
}
