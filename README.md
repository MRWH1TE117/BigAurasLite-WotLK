# BigAurasLite (WotLK 3.3.5a)

Big, clean aura icons for **target** and **focus** with smart priority, an optional secondary icon, precise timers, and a streamlined options panel. Built for **Wrath of the Lich King 3.3.5a** (Interface: 30300).

> Repository: **BigAurasLite-WotLK**

---

## ✨ Features

- **Main + Secondary** icons (top two important auras)
- **Smart priorities**: `IMMUNE` > `OFFENSE` > `DEFENSE` + optional **hardprio** per SpellID
- **Readable timers**: built-in numeric digits (can block OmniCC), cooldown spiral with alpha
- **Borders**: classic (Tooltip/Dialog) or **solid** (square/rounded) with thickness & inset
- **Category tags** (IMMUNE/OFFENSE/DEFENSE) for main and secondary icons
- **Visibility filters** (enemy/friend/both) and **minimum remaining time** on the main icon
- **Click-through** modes: off / on / “Hold modifier for tooltip” (ALT/SHIFT/CTRL)
- **Snap to grid** + **Pixel perfect**
- **Precise layout controls**: nudge arrows, X/Y/Scale fields, “Center”, **Mirror Focus ↔ Target**
- **Spells manager**: tracked list, edit (type/duration/note), reset to defaults, **Add from Target**
- **Testing tools**: quick tests & loops (target/focus, optional secondary)
- **Sound control**: **Play once per aura instance** (+ optional time-based cooldown)

---

## 📦 Installation

1. Download the `.zip` from **Releases** and **extract** it.
2. Place the **BigAurasLite** folder into:
   - Windows (typical WotLK clients): `World of Warcraft\Interface\AddOns\`
   - Make sure **BigAurasLite.toc** is directly inside the folder (no extra nesting).
3. Launch the game and enable the addon on the character select screen.

---

## 🧭 Quick Start

- Open options: **`/balopt`** (or Game Menu → AddOns → BigAurasLite).
- Unlock and drag frames: **General → Unlock frames (drag)**.
- Test:
  - `/bal test t` — test on target
  - `/bal test t second` — test with secondary icon
  - `/bal test f` / `/bal test f second` — same for focus
  - `/bal stoptest` — stop & clear tests
- Sound behavior: **Sound** tab → enable **Play sound only once per aura** (and optional cooldown).

---

## ⚙️ Options Overview

- **General**: combat-only, tooltip, chat log, category tag, “own timer” (block OmniCC-style digits)
- **Filters**: target filter (enemies/friends/both), min remaining time (seconds)
- **Style**: classic vs. solid border (square/rounded), edge/thickness/inset, font (preset/custom), outline, spiral alpha, base digit size
- **Layout**: content size, inset, strata, **X/Y/Scale** (Set/Center), nudge arrows `< > ^ v`, **Mirror Focus ↔ Target**
- **Secondary**: enable, anchor (below/above/left/right), scale, gap, offsets, min remain, tag
- **Precision**: click-through mode (off/on/hold + modifier), snap to grid (size), pixel perfect
- **Sound**: play once per aura instance, detection epsilon, optional time-based cooldown
- **Testing**: quick loops, reset UI/secondary/positions
- **Spells**: filter by category, search, edit (ID/type/duration/note), reset to defaults, **Add from Target (HELPFUL)**

---

## 🧩 Compatibility

- **OmniCC/tullaCC**: If you enable “Own timer (block OmniCC-style)”, BigAurasLite will show **only its own** digits on its icons (to avoid duplicates).
- Interface version: **30300** (WotLK 3.3.5a).

---

## 🔊 Sound: “Play Once” Explained

- When **Play sound only once per aura** is enabled, sounds trigger **only when the aura is newly applied/refreshed**, not on every tick.
- **Instance detect epsilon** (default 0.010s) helps differentiate a brand-new instance from the same one.
- **Also apply time cooldown** + **Cooldown (sec)** adds a simple time-based limiter (per category) if other addons/lag double-fire events.

---

## 🛠 Development

**Packaging a release:**

1. Ensure the folder name is `BigAurasLite`.
2. Zip the **contents** of that folder (so the zip root is `BigAurasLite/…`) as `BigAurasLite-vX.Y.Z.zip`.
3. Upload to GitHub **Releases**.

**Versioning:** `MAJOR.MINOR.PATCH` (e.g., `1.11.0`).

---

## 🐞 Troubleshooting

- **“?” on option buttons** — We use plain text arrows (`< > ^ v`), not icon textures. Seeing `?` is harmless; buttons still work.
- **Endless sounds** — Enable “Play sound only once per aura” and (optionally) the time cooldown.
- **Fractional positions** like `130.9999` — that’s UI scaling. Fields display rounded values; Set/Nudge stores rounded pixels.
- **Double digits on icons** — Either disable digits in OmniCC **or** enable “Own timer (block OmniCC-style)” here.

---

## 📜 License

MIT — see [`LICENSE`](./LICENSE).

---
