/**
 * Vantage · docs/assets/js/vantage.js
 * ------------------------------------------------------------------
 * A browser recreation of the components, for the documentation page.
 *
 * This is not the library — the library is Luau and runs in Roblox. What
 * this file reproduces is the *behaviour*, so the page can be used to
 * judge it: the ripple that starts under the pointer, the spring knob, the
 * sliding segmented indicator, the collapsing section, the notification
 * rail, the palette's keyboard model, and a theme system that morphs
 * rather than cuts.
 *
 * Colours come from `themes.js`, which is generated from the library's own
 * `Theme.derive`, so nothing here can drift from what ships.
 */

import { THEMES } from "./themes.js";

/* ── Theme ---------------------------------------------------------- */

const TOKEN_CSS = {
	canvas: "--canvas",
	surface: "--surface",
	surfaceAlt: "--surface-alt",
	sunken: "--sunken",
	elevated: "--elevated",
	raised: "--raised",
	overlay: "--overlay",
	borderSubtle: "--border-subtle",
	border: "--border",
	borderStrong: "--border-strong",
	text: "--text",
	textMuted: "--text-muted",
	textDim: "--text-dim",
	textInverted: "--text-inverted",
	hover: "--hover",
	pressed: "--pressed",
	trackOff: "--track-off",
	knob: "--knob",
	accent: "--accent",
	danger: "--danger",
	success: "--success",
	warning: "--warning",
	info: "--info",
	shadow: "--shadow",
	scrim: "--scrim"
};

export const themeState = { current: "obsidian" };

export function applyTheme(name) {
	const theme = THEMES.find((entry) => entry.name === name) ?? THEMES.find((entry) => entry.name === "obsidian");
	if (!theme) return;

	const root = document.documentElement;
	for (const [token, cssVar] of Object.entries(TOKEN_CSS)) {
		const value = theme.colors[token];
		if (value) root.style.setProperty(cssVar, value);
	}
	root.dataset.theme = theme.name;
	root.dataset.mode = theme.mode;
	themeState.current = theme.name;

	for (const button of document.querySelectorAll("[data-theme-card]")) {
		button.setAttribute("aria-pressed", String(button.dataset.themeCard === theme.name));
	}
	const select = document.querySelector("[data-theme-select]");
	if (select) select.value = theme.name;

	try {
		localStorage.setItem("vantage.theme", theme.name);
	} catch {
		/* private mode: the theme still applies, it just does not persist */
	}

	document.dispatchEvent(new CustomEvent("vantage:theme", { detail: theme }));
}

/* ── Helpers -------------------------------------------------------- */

const on = (target, event, handler, options) => target.addEventListener(event, handler, options);

function ripple(button, event) {
	const rect = button.getBoundingClientRect();
	const x = (event.clientX ?? rect.left + rect.width / 2) - rect.left;
	const y = (event.clientY ?? rect.top + rect.height / 2) - rect.top;
	// Reach the furthest corner, the way the library sizes its ripple.
	const radius = Math.max(
		Math.hypot(x, y),
		Math.hypot(rect.width - x, y),
		Math.hypot(x, rect.height - y),
		Math.hypot(rect.width - x, rect.height - y)
	);
	const node = document.createElement("span");
	node.className = "ripple";
	node.style.left = `${x}px`;
	node.style.top = `${y}px`;
	node.style.width = `${radius * 2}px`;
	node.style.height = `${radius * 2}px`;
	button.appendChild(node);
	setTimeout(() => node.remove(), 560);
}

/* ── Buttons -------------------------------------------------------- */

function wireButtons() {
	for (const button of document.querySelectorAll(".btn")) {
		on(button, "pointerdown", (event) => {
			if (button.disabled) return;
			ripple(button, event);
		});
	}
}

/* ── Toggles -------------------------------------------------------- */

function wireToggles() {
	for (const toggle of document.querySelectorAll(".toggle")) {
		on(toggle, "click", () => {
			const next = toggle.getAttribute("aria-checked") !== "true";
			toggle.setAttribute("aria-checked", String(next));
			const readout = toggle.closest(".row")?.querySelector("[data-readout]");
			if (readout) readout.textContent = String(next);
			document.dispatchEvent(new CustomEvent("vantage:toggle", { detail: { name: toggle.dataset.name, value: next } }));
		});
	}
}

/* ── Sliders -------------------------------------------------------- */

function wireSliders() {
	for (const slider of document.querySelectorAll(".slider")) {
		const fill = slider.querySelector(".fill");
		const knob = slider.querySelector(".knob");
		const readout = slider.parentElement?.querySelector("[data-readout]") ?? slider.querySelector(".value");
		const min = Number(slider.dataset.min ?? 0);
		const max = Number(slider.dataset.max ?? 1);
		const step = Number(slider.dataset.step ?? 0.01);
		const decimals = Number(slider.dataset.decimals ?? 2);
		const suffix = slider.dataset.suffix ?? "";
		const ticks = (slider.dataset.ticks ?? "").split(",").filter(Boolean).map(Number);
		let value = Number(slider.dataset.value ?? min);

		const render = () => {
			const fraction = (value - min) / (max - min || 1);
			fill.style.width = `${fraction * 100}%`;
			knob.style.left = `${fraction * 100}%`;
			if (readout) {
				readout.textContent = `${value.toFixed(decimals)}${suffix}`;
			}
			slider.setAttribute("aria-valuenow", String(value));
		};

		const setFromEvent = (event) => {
			const rect = slider.getBoundingClientRect();
			const fraction = Math.min(1, Math.max(0, (event.clientX - rect.left) / rect.width));
			let next = min + fraction * (max - min);
			next = Math.round(next / step) * step;
			if (ticks.length > 0) {
				// Snap to the nearest tick when one is close, the way a
				// stepped slider does in-game.
				const nearest = ticks.reduce((best, tick) => (Math.abs(tick - next) < Math.abs(best - next) ? tick : best), ticks[0]);
				const threshold = (max - min) * 0.05;
				if (Math.abs(nearest - next) < threshold) next = nearest;
			}
			value = Math.min(max, Math.max(min, next));
			render();
		};

		on(slider, "pointerdown", (event) => {
			slider.classList.add("dragging");
			slider.setPointerCapture?.(event.pointerId);
			setFromEvent(event);
		});
		on(slider, "pointermove", (event) => {
			if (slider.classList.contains("dragging")) setFromEvent(event);
		});
		const stop = () => slider.classList.remove("dragging");
		on(slider, "pointerup", stop);
		on(slider, "pointercancel", stop);

		on(slider, "keydown", (event) => {
			const big = event.shiftKey ? 10 : 1;
			if (event.key === "ArrowRight" || event.key === "ArrowUp") value = Math.min(max, value + step * big);
			else if (event.key === "ArrowLeft" || event.key === "ArrowDown") value = Math.max(min, value - step * big);
			else if (event.key === "Home") value = min;
			else if (event.key === "End") value = max;
			else return;
			event.preventDefault();
			render();
		});

		slider.tabIndex = 0;
		slider.setAttribute("role", "slider");
		render();
	}
}

/* ── Segmented ------------------------------------------------------ */

function wireSegmented() {
	for (const group of document.querySelectorAll(".segmented")) {
		const indicator = group.querySelector(".indicator");
		const buttons = [...group.querySelectorAll("button")];

		const move = (button, instant) => {
			const rect = button.getBoundingClientRect();
			const parent = group.getBoundingClientRect();
			if (instant) indicator.style.transition = "none";
			indicator.style.left = `${rect.left - parent.left}px`;
			indicator.style.width = `${rect.width}px`;
			if (instant) {
				requestAnimationFrame(() => {
					indicator.style.transition = "";
				});
			}
		};

		const select = (button) => {
			for (const entry of buttons) entry.setAttribute("aria-selected", String(entry === button));
			move(button);
			const readout = group.parentElement?.querySelector("[data-readout]");
			if (readout) readout.textContent = button.textContent.trim();
		};

		for (const button of buttons) on(button, "click", () => select(button));
		const active = buttons.find((button) => button.getAttribute("aria-selected") === "true") ?? buttons[0];
		requestAnimationFrame(() => move(active, true));
		on(window, "resize", () => move(buttons.find((button) => button.getAttribute("aria-selected") === "true") ?? buttons[0], true));
	}
}

/* ── Dropdown ------------------------------------------------------- */

function wireDropdowns() {
	for (const dropdown of document.querySelectorAll(".dropdown")) {
		const toggle = dropdown.querySelector(".dropdown-toggle");
		const panel = dropdown.querySelector(".dropdown-panel");
		const options = [...panel.querySelectorAll(".option")];
		const label = dropdown.querySelector("[data-label]");
		const readout = dropdown.closest(".row")?.querySelector("[data-readout]");
		let highlight = 0;

		const paint = () => options.forEach((option, index) => option.classList.toggle("highlight", index === highlight));

		const close = () => {
			dropdown.classList.remove("open");
			toggle.setAttribute("aria-expanded", "false");
		};

		const choose = (option) => {
			for (const entry of options) entry.setAttribute("aria-selected", String(entry === option));
			if (label) label.textContent = option.dataset.value ?? option.textContent.trim();
			if (readout) readout.textContent = option.dataset.value ?? option.textContent.trim();
			close();
		};

		on(toggle, "click", (event) => {
			event.stopPropagation();
			const open = dropdown.classList.toggle("open");
			toggle.setAttribute("aria-expanded", String(open));
			if (open) {
				highlight = Math.max(0, options.findIndex((option) => option.getAttribute("aria-selected") === "true"));
				paint();
			}
		});

		for (const [index, option] of options.entries()) {
			on(option, "mouseenter", () => {
				highlight = index;
				paint();
			});
			on(option, "click", () => choose(option));
		}

		on(dropdown, "keydown", (event) => {
			if (!dropdown.classList.contains("open")) return;
			if (event.key === "ArrowDown") highlight = Math.min(options.length - 1, highlight + 1);
			else if (event.key === "ArrowUp") highlight = Math.max(0, highlight - 1);
			else if (event.key === "Enter") choose(options[highlight]);
			else if (event.key === "Escape") close();
			else return;
			event.preventDefault();
			paint();
		});

		on(document, "click", (event) => {
			if (!dropdown.contains(event.target)) close();
		});
	}
}

/* ── Inputs --------------------------------------------------------- */

function wireInputs() {
	for (const wrap of document.querySelectorAll(".input")) {
		const input = wrap.querySelector("input");
		const counter = wrap.querySelector(".counter");
		const max = Number(input.getAttribute("maxlength") ?? 0);
		const update = () => {
			if (counter && max) counter.textContent = `${input.value.length}/${max}`;
		};
		on(input, "input", update);
		update();
	}
}

/* ── Keybind -------------------------------------------------------- */

const MODIFIER_LABELS = { Shift: "Shift", Control: "Ctrl", Alt: "Alt", Meta: "Meta" };

function formatChord(event) {
	const parts = [];
	for (const [key, label] of Object.entries(MODIFIER_LABELS)) {
		if (event.getModifierState?.(key) || event[`${key.toLowerCase()}Key`]) parts.push(label);
	}
	const code = event.key === " " ? "Space" : event.key;
	if (!MODIFIER_LABELS[code] && code !== "Shift" && code !== "Control" && code !== "Alt" && code !== "Meta") parts.push(code.toUpperCase());
	return parts.join("+");
}

function wireKeybinds() {
	for (const button of document.querySelectorAll(".keybind")) {
		const label = button.querySelector("[data-chord]");
		on(button, "click", () => {
			if (button.classList.contains("capturing")) {
				button.classList.remove("capturing");
				label.textContent = "Not set";
				return;
			}
			button.classList.add("capturing");
			label.textContent = "Press keys…";

			const finish = (event) => {
				event.preventDefault();
				button.classList.remove("capturing");
				window.removeEventListener("keydown", finish, true);
				const chord = formatChord(event);
				label.textContent = chord || "Not set";
				const readout = button.closest(".row")?.querySelector("[data-readout]");
				if (readout) readout.textContent = chord || "—";
			};
			window.addEventListener("keydown", finish, true);
		});
	}
}

/* ── Sections (collapse) -------------------------------------------- */

function wireCards() {
	for (const card of document.querySelectorAll(".card")) {
		const header = card.querySelector(":scope > header");
		const body = card.querySelector(":scope > .body");
		if (!header || !body) continue;
		on(header, "click", () => {
			const collapsed = card.classList.toggle("collapsed");
			if (collapsed) {
				body.style.height = `${body.scrollHeight}px`;
				requestAnimationFrame(() => {
					body.style.height = "0px";
				});
			} else {
				body.style.height = `${body.scrollHeight}px`;
				setTimeout(() => {
					if (!card.classList.contains("collapsed")) body.style.height = "auto";
				}, 280);
			}
		});
	}
}

/* ── Tabs ----------------------------------------------------------- */

function wireTabs() {
	for (const item of document.querySelectorAll("[data-tab]")) {
		on(item, "click", () => {
			const target = item.dataset.tab;
			for (const entry of document.querySelectorAll("[data-tab]")) {
				entry.classList.toggle("active", entry === item);
			}
			for (const panel of document.querySelectorAll("[data-panel]")) {
				panel.classList.toggle("active", panel.dataset.panel === target);
			}
		});
	}
}

/* ── Toasts (Notify) ------------------------------------------------- */

const toastKeys = new Map();

export function pushToast({ title, body, tone = "accent", duration = 4.5, key, actions = [] }) {
	const host = document.querySelector("[data-toasts]");
	if (!host) return null;
	if (key && toastKeys.has(key)) {
		// Grouping: the same key bumps a counter instead of stacking.
		const existing = toastKeys.get(key);
		existing.count += 1;
		existing.node.querySelector("[data-count]").textContent = `×${existing.count}`;
		existing.node.querySelector(".rail").style.animation = "none";
		void existing.node.offsetWidth;
		existing.node.querySelector(".rail").style.animation = `rail ${duration}s linear forwards`;
		return existing.node;
	}

	const node = document.createElement("div");
	node.className = `toast ${tone}`;
	node.innerHTML = `
		<strong>${title ?? "Notification"}<span class="count" data-count></span></strong>
		${body ? `<p>${body}</p>` : ""}
		<div class="actions"></div>
		<i class="rail" style="animation: rail ${duration}s linear forwards"></i>`;

	const actionHost = node.querySelector(".actions");
	for (const action of actions) {
		const button = document.createElement("button");
		button.className = `btn sm ${action.variant ?? "ghost"}`;
		button.textContent = action.text;
		on(button, "pointerdown", (event) => ripple(button, event));
		on(button, "click", () => {
			action.run?.();
			dismiss();
		});
		actionHost.appendChild(button);
	}
	if (actions.length === 0) actionHost.remove();

	host.appendChild(node);
	on(node, "pointerenter", () => {
		node.querySelector(".rail").style.animationPlayState = "paused";
	});
	on(node, "pointerleave", () => {
		node.querySelector(".rail").style.animationPlayState = "running";
	});

	const dismiss = () => {
		node.classList.add("leaving");
		if (key) toastKeys.delete(key);
		setTimeout(() => node.remove(), 260);
	};
	on(node, "click", (event) => {
		if (event.target.closest(".actions")) return;
		dismiss();
	});
	const timer = setTimeout(dismiss, duration * 1000);
	on(node, "pointerenter", () => clearTimeout(timer));

	if (key) toastKeys.set(key, { node, count: 1 });
	return node;
}

/* ── Modal ----------------------------------------------------------- */

export function openModal({ title, body, tone = "accent", confirm = "Confirm", cancel = "Cancel", onResult }) {
	const scrim = document.createElement("div");
	scrim.className = "modal-scrim";
	scrim.innerHTML = `
		<div class="modal" role="dialog" aria-modal="true">
			<h3>${title}</h3>
			<p>${body}</p>
			<div class="actions">
				<button class="btn secondary" data-cancel>${cancel}</button>
				<button class="btn ${tone === "danger" ? "danger" : "primary"}" data-confirm>${confirm}</button>
			</div>
		</div>`;

	const close = (result) => {
		scrim.remove();
		window.removeEventListener("keydown", onKey, true);
		onResult?.(result);
	};
	const onKey = (event) => {
		if (event.key === "Escape") {
			event.preventDefault();
			close(false);
		}
	};
	window.addEventListener("keydown", onKey, true);

	for (const button of scrim.querySelectorAll(".btn")) {
		on(button, "pointerdown", (event) => ripple(button, event));
	}
	on(scrim.querySelector("[data-cancel]"), "click", () => close(false));
	on(scrim.querySelector("[data-confirm]"), "click", () => close(true));
	on(scrim, "click", (event) => {
		if (event.target === scrim) close(false);
	});

	document.body.appendChild(scrim);
	scrim.querySelector("[data-confirm]").focus();
	return scrim;
}

/* ── Command palette ------------------------------------------------- */

const PALETTE_COMMANDS = [
	{ id: "theme-obsidian", label: "Switch to Obsidian", hint: "Theme", run: () => applyTheme("obsidian") },
	{ id: "theme-porcelain", label: "Switch to Porcelain", hint: "Theme", run: () => applyTheme("porcelain") },
	{ id: "theme-verdant", label: "Switch to Verdant", hint: "Theme", run: () => applyTheme("verdant") },
	{ id: "theme-amethyst", label: "Switch to Amethyst", hint: "Theme", run: () => applyTheme("amethyst") },
	{ id: "demo-loading", label: "Replay the loading screen", hint: "Demo", run: () => window.vantageLoading?.replay() },
	{ id: "demo-toast", label: "Push a notification", hint: "Demo", run: () => pushToast({ title: "Command palette", body: "Ran from Ctrl+K.", tone: "info" }) },
	{ id: "demo-modal", label: "Open a modal", hint: "Demo", run: () => openModal({ title: "Modal", body: "Opened from the command palette.", onResult: (value) => pushToast({ title: "Modal closed", body: `Result: ${value}`, tone: "success" }) }) },
	{ id: "docs-readme", label: "Open the README on GitHub", hint: "Docs", run: () => window.open("https://github.com/Irakli17/Ui-Library-Test#readme", "_blank", "noopener") }
];

export function openPalette() {
	const recents = JSON.parse(localStorage.getItem("vantage.recents") ?? "[]");
	const ordered = [...PALETTE_COMMANDS].sort((a, b) => recents.indexOf(b.id) - recents.indexOf(a.id));

	const scrim = document.createElement("div");
	scrim.className = "palette-scrim";
	scrim.innerHTML = `
		<div class="palette" role="dialog" aria-modal="true">
			<input type="text" placeholder="Type a command…" aria-label="Command palette search" />
			<ul role="listbox"></ul>
		</div>`;

	const input = scrim.querySelector("input");
	const list = scrim.querySelector("ul");
	let results = ordered;
	let highlight = 0;

	const render = (query = "") => {
		const needle = query.trim().toLowerCase();
		results = ordered.filter((command) => !needle || command.label.toLowerCase().includes(needle) || command.hint.toLowerCase().includes(needle));
		if (needle) results.sort((a, b) => a.label.toLowerCase().indexOf(needle) - b.label.toLowerCase().indexOf(needle));
		highlight = 0;
		list.innerHTML = results
			.map((command, index) => `<li role="option" data-index="${index}" class="${index === 0 ? "highlight" : ""}">${command.label}<span class="hint">${command.hint}</span></li>`)
			.join("");
		for (const item of list.querySelectorAll("li")) {
			on(item, "click", () => run(results[Number(item.dataset.index)]));
			on(item, "mouseenter", () => {
				highlight = Number(item.dataset.index);
				paint();
			});
		}
	};

	const paint = () => {
		for (const item of list.querySelectorAll("li")) {
			item.classList.toggle("highlight", Number(item.dataset.index) === highlight);
		}
	};

	const close = () => {
		scrim.remove();
		window.removeEventListener("keydown", onKey, true);
	};

	const run = (command) => {
		if (!command) return;
		const next = [command.id, ...recents.filter((id) => id !== command.id)].slice(0, 6);
		try {
			localStorage.setItem("vantage.recents", JSON.stringify(next));
		} catch {
			/* fine */
		}
		close();
		command.run();
	};

	const onKey = (event) => {
		if (event.key === "Escape") {
			event.preventDefault();
			close();
		} else if (event.key === "ArrowDown") {
			highlight = Math.min(results.length - 1, highlight + 1);
			paint();
			event.preventDefault();
		} else if (event.key === "ArrowUp") {
			highlight = Math.max(0, highlight - 1);
			paint();
			event.preventDefault();
		} else if (event.key === "Enter") {
			run(results[highlight]);
			event.preventDefault();
		}
	};

	on(input, "input", () => render(input.value));
	window.addEventListener("keydown", onKey, true);
	on(scrim, "click", (event) => {
		if (event.target === scrim) close();
	});

	document.body.appendChild(scrim);
	render();
	input.focus();
	return scrim;
}

/* ── Tooltips -------------------------------------------------------- */

function wireTooltips() {
	const tip = document.querySelector("[data-tooltip]");
	if (!tip) return;
	let timer = null;

	const hide = () => {
		clearTimeout(timer);
		tip.classList.remove("show");
	};

	for (const host of document.querySelectorAll("[data-tip]")) {
		on(host, "pointerenter", () => {
			const rect = host.getBoundingClientRect();
			clearTimeout(timer);
			// A dwell delay, like the library's, so tooltips do not flash.
			timer = setTimeout(() => {
				const [title, body] = host.dataset.tip.split("|");
				tip.innerHTML = title ? `<strong>${title}</strong><span>${body ?? ""}</span>` : `<span>${body ?? title ?? ""}</span>`;
				tip.classList.add("show");
				const tipRect = tip.getBoundingClientRect();
				let left = rect.left + rect.width / 2 - tipRect.width / 2;
				left = Math.max(8, Math.min(window.innerWidth - tipRect.width - 8, left));
				let top = rect.top - tipRect.height - 9;
				if (top < 8) top = rect.bottom + 9;
				tip.style.left = `${left}px`;
				tip.style.top = `${top}px`;
			}, 320);
		});
		on(host, "pointerleave", hide);
		on(host, "click", hide);
	}
}

/* ── Copy buttons ----------------------------------------------------- */

function wireCopy() {
	for (const button of document.querySelectorAll("[data-copy]")) {
		on(button, "click", async () => {
			const source = document.querySelector(button.dataset.copy);
			const text = source?.textContent?.trim() ?? "";
			const original = button.textContent;
			try {
				await navigator.clipboard.writeText(text);
				button.textContent = "Copied";
			} catch {
				button.textContent = "Select and copy";
			}
			button.classList.add("done");
			setTimeout(() => {
				button.textContent = original;
				button.classList.remove("done");
			}, 1600);
		});
	}
}

/* ── Status bar ------------------------------------------------------- */

function wireStatusbar() {
	const fpsNode = document.querySelector("[data-fps]");
	const pingNode = document.querySelector("[data-ping]");
	const memNode = document.querySelector("[data-mem]");
	if (!fpsNode) return;

	let frames = 0;
	let last = performance.now();
	let fps = 60;
	const ping = 38 + Math.round(Math.random() * 12);
	let memory = 412;

	const loop = (now) => {
		frames += 1;
		if (now - last >= 500) {
			fps = Math.round((frames * 1000) / (now - last));
			frames = 0;
			last = now;
			fpsNode.textContent = `${fps} fps`;
			if (pingNode) pingNode.textContent = `${ping + Math.round(Math.random() * 3)} ms`;
			memory += Math.random() * 2.4 - 1;
			if (memNode) memNode.textContent = `${memory.toFixed(1)} MB`;
		}
		requestAnimationFrame(loop);
	};
	requestAnimationFrame(loop);
}

/* ── Boot ------------------------------------------------------------- */

export function boot() {
	let saved = null;
	try {
		saved = localStorage.getItem("vantage.theme");
	} catch {
		saved = null;
	}
	applyTheme(saved ?? "obsidian");

	wireButtons();
	wireToggles();
	wireSliders();
	wireSegmented();
	wireDropdowns();
	wireInputs();
	wireKeybinds();
	wireCards();
	wireTabs();
	wireTooltips();
	wireCopy();
	wireStatusbar();

	for (const select of document.querySelectorAll("[data-theme-select]")) {
		select.innerHTML = THEMES.map((theme) => `<option value="${theme.name}">${theme.label}</option>`).join("");
		select.value = themeState.current;
		on(select, "change", () => applyTheme(select.value));
	}

	for (const card of document.querySelectorAll("[data-theme-card]")) {
		on(card, "click", () => applyTheme(card.dataset.themeCard));
	}

	on(document, "keydown", (event) => {
		if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k") {
			event.preventDefault();
			openPalette();
		}
	});

	for (const trigger of document.querySelectorAll("[data-open-palette]")) {
		on(trigger, "click", () => openPalette());
	}

	return { applyTheme, pushToast, openModal, openPalette };
}
