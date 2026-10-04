/**
 * Vantage · docs/assets/js/easing.js
 * ------------------------------------------------------------------
 * The easing library, ported line-for-line from `src/Core/Easing.luau`
 * so the curves drawn here are the curves that run in Roblox — including
 * the cubic-bezier solver, which is Newton-Raphson with a bisection
 * fallback, exactly like the Luau version.
 *
 * The gallery evaluates each function at 120 samples and draws the result,
 * then animates a runner with the same function. Nothing is approximated
 * with a lookalike CSS timing function.
 */

/* ── The ported library ---------------------------------------------- */

const PI = Math.PI;
const pow = Math.pow;
const sin = Math.sin;
const cos = Math.cos;
const sqrt = Math.sqrt;
const abs = Math.abs;

const linear = (t) => t;
const quadIn = (t) => t * t;
const quadOut = (t) => -t * (t - 2);
const quadInOut = (t) => {
	t *= 2;
	if (t < 1) return 0.5 * t * t;
	t -= 1;
	return -0.5 * (t * (t - 2) - 1);
};
const cubicIn = (t) => t * t * t;
const cubicOut = (t) => {
	t -= 1;
	return t * t * t + 1;
};
const cubicInOut = (t) => {
	t *= 2;
	if (t < 1) return 0.5 * t * t * t;
	t -= 2;
	return 0.5 * (t * t * t + 2);
};
const quartIn = (t) => t * t * t * t;
const quartOut = (t) => {
	t -= 1;
	return 1 - t * t * t * t;
};
const quartInOut = (t) => {
	t *= 2;
	if (t < 1) return 0.5 * t * t * t * t;
	t -= 2;
	return -0.5 * (t * t * t * t - 2);
};
const quintIn = (t) => t * t * t * t * t;
const quintOut = (t) => {
	t -= 1;
	return t * t * t * t * t + 1;
};
const quintInOut = (t) => {
	t *= 2;
	if (t < 1) return 0.5 * t * t * t * t * t;
	t -= 2;
	return 0.5 * (t * t * t * t * t + 2);
};
const sineIn = (t) => 1 - cos(t * PI * 0.5);
const sineOut = (t) => sin(t * PI * 0.5);
const sineInOut = (t) => -0.5 * (cos(PI * t) - 1);
const expoIn = (t) => (t <= 0 ? 0 : pow(2, 10 * t - 10));
const expoOut = (t) => (t >= 1 ? 1 : 1 - pow(2, -10 * t));
const expoInOut = (t) => {
	if (t <= 0) return 0;
	if (t >= 1) return 1;
	t *= 2;
	if (t < 1) return 0.5 * pow(2, 10 * (t - 1));
	return 0.5 * (2 - pow(2, -10 * (t - 1)));
};
const circIn = (t) => 1 - sqrt(1 - t * t);
const circOut = (t) => {
	t -= 1;
	return sqrt(1 - t * t);
};
const circInOut = (t) => {
	t *= 2;
	if (t < 1) return -0.5 * (sqrt(1 - t * t) - 1);
	t -= 2;
	return 0.5 * (sqrt(1 - t * t) + 1);
};
const backOut = (t, s = 1.70158) => {
	t -= 1;
	return t * t * ((s + 1) * t + s) + 1;
};
const elasticOut = (t) => {
	if (t <= 0) return 0;
	if (t >= 1) return 1;
	const p = 0.3;
	return pow(2, -10 * t) * sin((t - p / 4) * ((2 * PI) / p)) + 1;
};
const oscInOut = (t, a) => {
	const w = (2 * PI) / 3.4;
	if (t === 0) return 0;
	if (t === 1) return 1;
	return 1 + a * pow(2, -10 * t) * sin(w * t - w / 4);
};
const oscillate = (t) => oscInOut(t, -0.6);
const settle = (t) => oscInOut(t, -0.28);
const bounceOut = (t) => {
	if (t < 1 / 2.75) return 7.5625 * t * t;
	if (t < 2 / 2.75) {
		t -= 1.5 / 2.75;
		return 7.5625 * t * t + 0.75;
	}
	if (t < 2.5 / 2.75) {
		t -= 2.25 / 2.75;
		return 7.5625 * t * t + 0.9375;
	}
	t -= 2.625 / 2.75;
	return 7.5625 * t * t + 0.984375;
};
const smooth = (t) => t * t * (3 - 2 * t);
const smoother = (t) => t * t * t * (t * (t * 6 - 15) + 10);
const snapEase = (t) => 1 - pow(1 - t, 4.6);
const glide = (t) => (t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2);

const bezierComponent = (t, a1, a2) => {
	const mt = 1 - t;
	return 3 * mt * mt * t * a1 + 3 * mt * t * t * a2 + t * t * t;
};
const bezierSlope = (t, a1, a2) => {
	const mt = 1 - t;
	return 3 * mt * mt * a1 + 6 * mt * t * (a2 - a1) + 3 * t * t * (1 - a2);
};

export function bezier(x1, y1, x2, y2) {
	if (x1 === y1 && x2 === y2) return linear;

	const EPSILON = 1e-7;
	const solve = (progress) => {
		if (progress <= 0) return 0;
		if (progress >= 1) return 1;

		let t = progress;
		for (let index = 0; index < 8; index += 1) {
			const x = bezierComponent(t, x1, x2) - progress;
			if (abs(x) < EPSILON) return t;
			const slope = bezierSlope(t, x1, x2);
			if (abs(slope) < 1e-6) break;
			t -= x / slope;
		}

		let low = 0;
		let high = 1;
		t = progress;
		for (let index = 0; index < 24; index += 1) {
			const x = bezierComponent(t, x1, x2);
			if (abs(x - progress) < EPSILON) break;
			if (x < progress) low = t;
			else high = t;
			t = (low + high) * 0.5;
		}
		return t;
	};

	return (progress) => {
		if (progress <= 0) return 0;
		if (progress >= 1) return 1;
		return bezierComponent(solve(progress), y1, y2);
	};
}

/** Mirrors `Easing.catalog` — the named easings components ask for by string. */
export const CATALOG = {
	linear,
	glide,
	smooth: smoother,
	move: bezier(0.4, 0, 0.2, 1),
	moveIn: bezier(0.4, 0, 1, 1),
	moveOut: bezier(0, 0, 0.2, 1),
	enter: bezier(0.05, 0.7, 0.1, 1),
	enterSoft: bezier(0.22, 1, 0.36, 1),
	enterSnap: bezier(0.16, 1, 0.3, 1),
	exit: bezier(0.3, 0, 0.8, 0.15),
	exitSoft: bezier(0.4, 0, 0.6, 1),
	emphasize: bezier(0.2, 0, 0, 1.2),
	emphasizeIn: bezier(0.7, -0.4, 0.84, 0.4),
	settle,
	oscillate,
	snap: snapEase,
	quad: quadInOut,
	cubic: cubicInOut,
	quart: quartInOut,
	quint: quintInOut,
	sine: sineInOut,
	expo: expoInOut,
	circ: circInOut,
	back: backOut,
	bounce: bounceOut,
	elastic: elasticOut
};

/* ── The gallery ------------------------------------------------------ */

// A deliberate spread: the ones the library actually reaches for, plus the
// classics people look for when judging a motion system. These are all
// transitions — they leave 0 and arrive at 1. `settle` and `oscillate` are
// deliberately absent: they are wobble curves (used by `Motion.breathe` and
// `Motion.pulse`), not transitions, and plotting them here would be a lie.
const SHOWN = [
	{ name: "move", note: "reorder · resize", fn: CATALOG.move },
	{ name: "enterSnap", note: "arriving · decelerate hard", fn: CATALOG.enterSnap },
	{ name: "enter", note: "arriving · softer start", fn: CATALOG.enter },
	{ name: "exit", note: "leaving · accelerate away", fn: CATALOG.exit },
	{ name: "emphasize", note: "moments · overshoots", fn: CATALOG.emphasize },
	{ name: "snap", note: "tooltips · whisper in", fn: CATALOG.snap },
	{ name: "glide", note: "symmetric · soft ends", fn: CATALOG.glide },
	{ name: "quad", note: "standard ease-in-out", fn: CATALOG.quad },
	{ name: "backOut", note: "classic overshoot", fn: CATALOG.back },
	{ name: "bounceOut", note: "impact", fn: CATALOG.bounce },
	{ name: "elasticOut", note: "rubber", fn: CATALOG.elastic },
	{ name: "expoOut", note: "brutal deceleration", fn: CATALOG.expo }
];

const SAMPLES = 140;
const DURATION = 900;

function drawPath(container, fn) {
	const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
	svg.setAttribute("viewBox", "0 0 160 78");
	svg.setAttribute("preserveAspectRatio", "none");
	svg.setAttribute("aria-hidden", "true");

	// The baseline and the target line, so overshoot is legible as overshoot.
	for (const value of [0, 1]) {
		const grid = document.createElementNS("http://www.w3.org/2000/svg", "line");
		grid.setAttribute("class", "grid");
		grid.setAttribute("x1", "8");
		grid.setAttribute("x2", "152");
		const y = 60 - value * 42;
		grid.setAttribute("y1", String(y));
		grid.setAttribute("y2", String(y));
		svg.appendChild(grid);
	}

	const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
	let d = "";
	for (let index = 0; index <= SAMPLES; index += 1) {
		const t = index / SAMPLES;
		const x = 8 + t * 144;
		const y = 60 - fn(t) * 42;
		d += `${index === 0 ? "M" : "L"}${x.toFixed(2)} ${y.toFixed(2)}`;
	}
	path.setAttribute("d", d);
	svg.appendChild(path);
	container.appendChild(svg);
}

export function buildEaseGallery(grid) {
	for (const entry of SHOWN) {
		const card = document.createElement("article");
		card.className = "ease-card";
		card.title = "Click to replay";

		const curve = document.createElement("div");
		drawPath(curve, entry.fn);

		const runner = document.createElement("div");
		runner.className = "runner";
		const dot = document.createElement("i");
		runner.appendChild(dot);

		const label = document.createElement("strong");
		label.textContent = entry.name;

		const note = document.createElement("span");
		note.textContent = entry.note;

		card.append(curve, runner, label, note);
		grid.appendChild(card);

		let frame = null;
		const run = () => {
			if (frame) cancelAnimationFrame(frame);
			const width = runner.clientWidth || 160;
			const start = performance.now();
			const tick = (now) => {
				const t = Math.min(1, (now - start) / DURATION);
				const value = entry.fn(t);
				dot.style.left = `${(value * (width - 6)).toFixed(2)}px`;
				if (t < 1) frame = requestAnimationFrame(tick);
				else frame = null;
			};
			frame = requestAnimationFrame(tick);
		};

		card.addEventListener("pointerenter", run);
		card.addEventListener("click", run);
		// Demonstrate it once on arrival without stealing focus.
		if (typeof IntersectionObserver === "function") {
			const observer = new IntersectionObserver((records) => {
				for (const record of records) {
					if (record.isIntersecting) {
						run();
						observer.disconnect();
					}
				}
			}, { threshold: 0.4 });
			observer.observe(card);
		}
	}
}
