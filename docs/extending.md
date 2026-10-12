# Extending TingUI

<sub>[Docs](README.md) › Extending</sub>

Add your own elements, themes, particles, icons and scenes. They get the theme, flags, configs, hover explanations and the command palette for free.

- [Elements](#elements)
- [Themes](#themes)
- [Particles](#particles)
- [Scenes](#scenes)
- [Icons](#icons)
- [Fader](#fader)
- [Helpers](#helpers)

## Elements

```lua
-- a +/- number stepper, available as group:AddStepper({...})
TingUI:RegisterElement("Stepper", function(group, o, api)
	local opt = api.NewOption("Stepper", o)          -- gives :OnChanged, :SetVisible, :SetDescription, ...
	opt.Value = o.Default or 0
	local row = api.Row(group._container, 24)
	opt.Row = row
	local label = api.New("TextLabel", { Text = (o.Text or "Stepper") .. ": " .. opt.Value, Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	function opt:Set(v, silent)
		self.Value = v
		label.Text = (o.Text or "Stepper") .. ": " .. v
		if not silent then api.Fire(self, v) end
	end
	api.Register(opt, o.Flag)                        -- saved in configs
	api.Catalog(group, opt, o.Text)                  -- searchable in Ctrl+K
	if o.Description then opt:SetDescription(o.Description) end
	return opt
end)
```

`api` (also `TingUI.API`) contains `New, Corner, Stroke, Pad, List, Row, Tween, Glow, Icon, NewOption, Register, Fire, Connect, Describe, Catalog, AccentOverlay, SafeCall, Theme, Gui, Overlay, ShowPopup, ClosePopup, Dragger`. `api.New(class, props, children)` accepts `Theme = {BackgroundColor3 = "Group"}`, so the property follows theme changes automatically.

## Themes

```lua
TingUI:RegisterTheme("Matcha", {
	Accent = Color3.fromRGB(140, 200, 120), Background = Color3.fromRGB(14, 17, 13),
	Style = { Radius = 1.3, Font = "Nunito", Particles = "Petals", Scene = "Abyss" },
}, "Soft greens and drifting leaves.")
```

The third argument is the line shown under the config tab's Preset dropdown. [Themes](themes.md#style-keys) lists every colour and style key.

## Particles

```lua
TingUI:RegisterParticles("Leaves", {
	Build = function(f, color, parent)               -- f.X, f.Y (0-1), f.Phase and f.Sway are pre-filled
		f.Speed, f.Base = 0.03 + math.random() * 0.03, 0.3
		f.Frame = Instance.new("Frame")
		f.Frame.Size = UDim2.fromOffset(10, 6)
		f.Frame.BackgroundColor3 = color
		f.Frame.Parent = parent
	end,
	Update = function(f, dt, t, speed)               -- may return a transparency; fading is handled for you
		f.Y = (f.Y + f.Speed * speed * dt) % 1
		f.Frame.Rotation = t * 60 + f.Phase * 50
		f.Frame.Position = UDim2.fromScale(f.X + math.sin(t + f.Phase) * 0.03, f.Y)
	end,
})
```

The new kind shows up in the config tab's particle dropdown straight away. Under reduced motion, `dt` is `0`, so particles hold still on their own.

## Scenes

A scene is living artwork drawn in and around every window that uses it. Hologram, Circuit and Abyss are built this way. Register one, then name it in a theme's `Style.Scene`.

```lua
TingUI:RegisterScene("Fireflies", {
	Build = function(S)
		S.Flies = {}
		for _ = 1, 24 do
			local dot = Instance.new("Frame")
			dot.AnchorPoint = Vector2.new(0.5, 0.5)
			dot.Size = UDim2.fromOffset(4, 4)
			dot.BorderSizePixel = 0
			dot.BackgroundTransparency = 1
			Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
			dot.Parent = S.Root
			table.insert(S.Flies, { Frame = dot, X = S.Rng:NextNumber(-40, S.W + 40), Y = S.Rng:NextNumber(-40, S.H + 40),
				Phase = S.Rng:NextNumber(0, 6.28), Glow = 0 })
		end
	end,
	Paint = function(S)                               -- runs on every theme change
		for _, f in ipairs(S.Flies) do f.Frame.BackgroundColor3 = TingUI.Theme.Accent end
	end,
	Update = function(S, dt, t)                       -- every frame while the window is visible
		for _, f in ipairs(S.Flies) do
			f.X = f.X + math.sin(t * 0.7 + f.Phase) * 12 * dt
			f.Y = f.Y + math.cos(t * 0.5 + f.Phase) * 9 * dt
			if S.Mouse and (S.Mouse - Vector2.new(f.X, f.Y)).Magnitude < 60 then f.Glow = 1 end
			f.Glow = math.max(f.Glow - dt * 1.5, 0)
			local blink = 0.5 + 0.5 * math.sin(t * 2 + f.Phase)
			f.Frame.Position = UDim2.fromOffset(f.X, f.Y)
			f.Frame.BackgroundTransparency = S.Fade(0.75 - 0.5 * math.max(blink, f.Glow))
		end
	end,
	Feedback = function(S, kind, x, y)                -- "Click", "Tab" or "Open"
		if kind ~= "Click" then return end
		for _, f in ipairs(S.Flies) do
			if Vector2.new(f.X - x, f.Y - y).Magnitude < 120 then f.Glow = 1 end
		end
	end,
})

TingUI:RegisterTheme("Summer Night", { Accent = Color3.fromRGB(255, 220, 120), Style = { Scene = "Fireflies", Particles = "Fireflies" } })
```

| Function | When it runs |
|---|---|
| `Build(S)` | Once, when a window first needs the scene. Required. |
| `Paint(S)` | On every theme change. Recolour from `TingUI.Theme` and `TingUI.Style` here. |
| `Update(S, dt, t)` | Every frame while the window is visible. |
| `Feedback(S, kind, x, y)` | When the player clicks the window (`"Click"`), switches tab (`"Tab"`) or opens it (`"Open"`). `x, y` are in window pixels. |

| Field on `S` | What it is |
|---|---|
| `S.Root` | A frame the size of the window, **behind** its content. It isn't clipped, so art can spill around the window. |
| `S.Top` | A frame the size of the window, **over** its content and clipped to it. Use it for sweeps and flashes. |
| `S.W`, `S.H` | The window's size in pixels. |
| `S.Mouse` | The pointer in window pixels, or `nil` when it's far away. |
| `S.P` | Presence from 0 to 1. It eases during theme crossfades. |
| `S.Fade(tr)` | Blends a transparency by presence. Wrap every transparency you set with it so the scene crossfades cleanly. |
| `S.Still` | `true` under reduced motion. `dt` is `0` then, and feedback isn't sent. |
| `S.Rng` | A `Random` seeded per scene, so the layout is the same every time. |
| `S.T` | Seconds the scene has been running. |

TingUI handles the rest. A scene pauses while its window is hidden, is destroyed when no theme uses it, and is switched off with one warning if any of its functions errors. Re-registering a name rebuilds it everywhere, which is handy while you iterate. `TingUI.SceneKinds` lists what's registered.

> [!TIP]
> Keep a scene to a few hundred frames, and reuse frames from a pool for short effects like ripples and bursts instead of creating new ones each time. The built-in scenes stay under about 2,000 instances per window.

## Icons

The built-in icons are `window, scan, keyboard, command, user, bell, check, cross, warn, info, discord, gear, snow, list, heart, chevron, search, eye, sparkle, lock, palette`. They're 96 px white PNGs tinted to the theme. On load TingUI draws crisp vector versions immediately, downloads the PNGs in the background (`AssetBase`, then GitHub, then jsDelivr), caches them in `<CacheFolder>/icons/v1/` and fades each icon over to its image. Without `writefile` and `getcustomasset`, or with `NoImages = true`, the vector icons stay.

To use your own, pass `Icons = {gear = "rbxassetid://..."}` in the load options, set `TingUI.IconAssets.gear = "..."` before building the UI, or draw one:

```lua
-- drawn on a 16 x 16 grid with rounded segments and dots
TingUI:RegisterIcon("heart", function(frame, size, colorKey, h)
	h.Dot(5.5, 6, 5); h.Dot(10.5, 6, 5); h.Seg(3.4, 8.2, 8, 13, 3); h.Seg(12.6, 8.2, 8, 13, 3)
end)
```

To change or add PNGs, edit and run `tools/build_icons.py` (Python with `cairosvg` and `Pillow`), then upload `assets/icons/` to your repo.

## Fader

`TingUI.Fader(frame)` fades a whole tree like a CanvasGroup's `GroupTransparency`, but keeps text rendered natively. CanvasGroups rasterise their contents, which makes text soft. Hints, notifications and the confirm dialog use it. Methods: `f:Tween(seconds, alpha)`, `f:Set(alpha)` and `f:Hide()`. Give an object the attribute `NoFade` if it animates its own transparency.

## Helpers

```lua
local res, err = TingUI:Request({ Url = url, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = json })
-- uses whichever of request / http_request / syn.request / http.request the executor has; nil + message if none

TingUI:Clipboard("text")   -- setclipboard / toclipboard; returns false if unsupported
```

`TingUI.Signal()` makes a signal like the ones in `TingUI.Events`. `TingUI.Environment` reports what the executor supports (see [Executors](executors.md#the-environment-report)).

---

**Next:** [Changelog](changelog.md) · [Roadmap](roadmap.md)
