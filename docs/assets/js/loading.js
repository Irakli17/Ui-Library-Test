/**
 * Vantage · docs/assets/js/loading.js
 * ------------------------------------------------------------------
 * The loading screen, recreated with the same maths `LogoWave` uses.
 *
 * The mark is cut into N horizontal bands. Each band is a clipping window
 * that is taller than its own slice by a computed bleed, with the whole
 * image drawn inside it at a matching offset — so neighbours overlap and
 * there are no seams. Every frame, each window is offset by
 *
 *     offset = sin(elapsed · speed · 2π − band · frequency · 2π) · amplitude
 *
 * and the phase is distributed across the bands. That is the whole trick:
 * a travelling wave, not a pulse.
 *
 * Progress here is simulated (the browser has no ContentProvider), but the
 * phase names, weights and tips are the ones the library uses.
 */

const on = (target, event, handler) => target.addEventListener(event, handler);

const PHASES = [
	{ name: "Preparing", weight: 0.08, detail: "Reading configuration" },
	{ name: "Streaming assets", weight: 0.78, detail: "Preloading interface assets" },
	{ name: "Finalising", weight: 0.14, detail: "Warming the animation engine" }
];

const TIPS = [
	"Press {TOGGLE} at any time to show or hide the interface.",
	"Every control in Vantage supports keyboard navigation.",
	"Theme changes morph rather than cut, so nothing flashes.",
	"Hold Shift on a slider for fine adjustment.",
	"Right-click a keybind to clear it.",
	"ContentProvider preloading happens in parallel with your gameplay setup."
];

export function createLoadingDemo(root) {
	const wave = root.querySelector("[data-wave]");
	const bar = root.querySelector("[data-bar]");
	const percent = root.querySelector("[data-percent]");
	const phaseLabel = root.querySelector("[data-phase]");
	const detail = root.querySelector("[data-detail]");
	const tipLabel = root.querySelector("[data-tip-text]");
	const continueButton = root.querySelector("[data-continue]");
	// The controls that belong to the demo rather than to the screen itself
	// live outside the 16:9 stage, so look there as a fallback.
	const safeToggle = root.querySelector("[data-autocontinue]") ?? document.querySelector("[data-autocontinue]");
	const replayButton = root.querySelector("[data-replay]") ?? document.querySelector("[data-replay]");

	const state = {
		slices: Number(root.dataset.slices ?? 34),
		amplitude: Number(root.dataset.amplitude ?? 5.5),
		frequency: Number(root.dataset.frequency ?? 1.15),
		speed: Number(root.dataset.speed ?? 0.42),
		progress: 0,
		elapsed: 0,
		running: false,
		continued: false,
		autoContinue: 2.4,
		autoRemaining: 0,
		startedAt: 0,
		tipIndex: 0
	};

	let bands = [];

	function build() {
		const rect = wave.getBoundingClientRect();
		const width = Math.round(rect.width) || 96;
		const height = Math.round(rect.height) || 96;
		const total = state.slices;
		const slice = height / total;

		// Same bleed formula the library uses: one phase step of travel plus a
		// couple of pixels, so a band can move by a full amplitude without ever
		// showing a gap above or below itself.
		const phaseStep = (state.frequency * Math.PI * 2) / total;
		const bleed = Math.max(2, Math.ceil(state.amplitude * (phaseStep + 2 / total)) + 2);

		wave.innerHTML = "";
		bands = [];

		for (let index = 0; index < total; index += 1) {
			const band = document.createElement("i");
			band.className = "band";
			// Every band is the whole image, clipped to its own slice: the
			// image is drawn at full size and shifted up by exactly one slice
			// per band, so the slices reassemble into the mark.
			band.style.top = `${(index * slice - bleed).toFixed(2)}px`;
			band.style.height = `${(slice + bleed * 2).toFixed(2)}px`;
			band.style.backgroundSize = `${width}px ${height}px`;
			band.style.backgroundPosition = `0 ${(bleed - index * slice).toFixed(2)}px`;
			band.dataset.band = String(index);
			wave.appendChild(band);
			bands.push({
				node: band,
				// Where this band sits on the mark, 0 at the top, 1 at the bottom.
				position: (index + 0.5) / total,
				// The phase lag that makes the wave travel instead of pulse.
				phase: ((index + 0.5) / total) * Math.PI * 2 * state.frequency
			});
		}
	}

	function frame(now) {
		if (!state.running) return;
		if (!state.last) state.last = now;
		const dt = Math.min((now - state.last) / 1000, 1 / 20);
		state.last = now;
		state.elapsed += dt;
		// The wave keeps moving across the whole run, including the wait for
		// the player, which is what the library does too.

		// Wave ---------------------------------------------------------
		for (const entry of bands) {
			const angle = state.elapsed * state.speed * Math.PI * 2 - entry.phase;
			// Envelope: the wave is strongest across the middle of the mark and
			// settles at the edges, so the silhouette stays readable.
			const distance = Math.abs(entry.position - 0.5) * 2;
			const envelope = Math.max(0.3, 1 - distance * distance * 0.7);
			const offset = Math.sin(angle) * state.amplitude * envelope;
			entry.node.style.transform = `translateY(${offset.toFixed(2)}px)`;
		}

		// Progress -----------------------------------------------------
		if (state.progress < 1) {
			state.progress = Math.min(1, state.elapsed / 3.2);
			bar.style.width = `${(state.progress * 100).toFixed(1)}%`;
			percent.textContent = `${Math.floor(state.progress * 100)}%`;

			let consumed = 0;
			for (const phase of PHASES) {
				consumed += phase.weight;
				if (state.progress <= consumed) {
					if (phaseLabel.textContent !== phase.name) {
						phaseLabel.textContent = phase.name;
						detail.textContent = phase.detail;
					}
					break;
				}
			}
		} else if (!state.continued) {
			// Preloading is done. Say so, instead of leaving the last phase name
			// on screen while the player decides.
			if (phaseLabel.textContent !== "Ready") {
				phaseLabel.textContent = "Ready";
				detail.textContent = state.autoContinue > 0 ? "Starting shortly" : "Waiting for you";
			}
			if (state.autoContinue > 0) {
				if (state.autoRemaining <= 0) state.autoRemaining = state.autoContinue;
				state.autoRemaining -= dt;
				continueButton.textContent = `Continue  ·  ${Math.max(0, state.autoRemaining).toFixed(1)}s`;
				if (state.autoRemaining <= 0) {
					continueScreen();
					return;
				}
			} else {
				continueButton.textContent = "Continue";
			}
			continueButton.classList.add("show");
		}

		// Tips ---------------------------------------------------------
		if (Math.floor(state.elapsed / 4.6) !== state.tipIndex) {
			state.tipIndex = Math.floor(state.elapsed / 4.6);
			tipLabel.style.opacity = "0";
			setTimeout(() => {
				tipLabel.textContent = TIPS[state.tipIndex % TIPS.length];
				tipLabel.style.opacity = "1";
			}, 260);
		}

		requestAnimationFrame(frame);
	}

	function start() {
		state.running = true;
		state.continued = false;
		state.progress = 0;
		state.elapsed = 0;
		state.autoRemaining = 0;
		state.last = performance.now();
		state.tipIndex = 0;
		bar.style.width = "0%";
		percent.textContent = "0%";
		continueButton.classList.remove("show");
		tipLabel.textContent = TIPS[0];
		tipLabel.style.opacity = "1";
		phaseLabel.textContent = PHASES[0].name;
		detail.textContent = PHASES[0].detail;
		root.classList.remove("done");
		build();
		requestAnimationFrame(frame);
	}

	function continueScreen() {
		state.continued = true;
		state.running = false;
		continueButton.classList.remove("show");
		root.classList.add("done");
		phaseLabel.textContent = "Ready";
		detail.textContent = "Handing over to the interface";
	}

	function configure(patch) {
		const wasRunning = state.running;
		Object.assign(state, patch);
		// Rebuilding is cheap (a few dozen nodes) and keeps the wave exact when
		// slices, amplitude or frequency change, running or not.
		build();
		state.last = 0;
		if (!wasRunning) {
			// A still frame, so a paused screen still shows the wave's shape.
			for (const entry of bands) {
				const distance = Math.abs(entry.position - 0.5) * 2;
				const envelope = Math.max(0.3, 1 - distance * distance * 0.7);
				const offset = Math.sin(-entry.phase) * state.amplitude * envelope;
				entry.node.style.transform = `translateY(${offset.toFixed(2)}px)`;
			}
		}
	}

	// A resize changes the pixel size of the mark, so the slice geometry has
	// to be recomputed — exactly the kind of thing a real UI library has to
	// handle and most screen mockups forget about.
	let resizeTimer = null;
	on(window, "resize", () => {
		clearTimeout(resizeTimer);
		resizeTimer = setTimeout(() => configure({}), 120);
	});

	if (safeToggle) {
		// The generic toggle wiring already flips the switch and announces it,
		// so this listens instead of binding a second click handler. Two
		// handlers on one switch would flip it twice and cancel out.
		safeToggle.dataset.name = "autoContinue";
		document.addEventListener("vantage:toggle", (event) => {
			if (event.detail?.name !== "autoContinue") return;
			// `false` in the library means "wait for the player".
			state.autoContinue = event.detail.value ? 2.4 : 0;
			state.autoRemaining = 0;
			if (!state.autoContinue) continueButton.textContent = "Continue";
		});
	}
	if (continueButton) continueButton.addEventListener("click", continueScreen);

	replayButton?.addEventListener("click", start);

	build();
	start();

	return { start, replay: start, configure, state };
}
