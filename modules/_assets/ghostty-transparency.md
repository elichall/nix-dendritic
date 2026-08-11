# Ghostty Background Transparency (postmortem)

When did it happen: 2026-08-11. Config involved: `modules/theme.nix` (generated
GTK CSS). Outcome: fixed by scoping one CSS rule; ghostty transparency and blur
now work. This doc explains the mechanism so the trap is not re-introduced.

Follow-ups the same day: the otter-launcher window stayed opaque (stale GTK
process), and waybar's workspace numbers turned uniform white (`label` rule).
The end state: the generated GTK CSS is now **palette-only** — no element rules
at all — because it is user-priority CSS loaded by every GTK3/GTK4 app.

## Symptom

`background-opacity = 0.5` + `background-blur = 20` (in the ghostty generated
config, `modules/theme.nix`) produced a terminal background that looked *lighter*
than the theme but was never see-through, and never blurred. kitty with
`background_opacity=0.5` was correctly transparent on the same stack, which
proved the compositor was fine and the problem was client-side (GTK/ghostty).

## Root cause

The theme generation writes a per-user GTK CSS linked into
`~/.config/gtk-{3,4}.0/gtk.css` so plain GTK apps follow the system palette. It
contained this rule:

```css
window, .background {
  background-color: @theme_bg_color;   /* opaque #0a1e24 */
  color: @theme_fg_color;
}
```

The `window` selector matches the root node of **every** GTK4 window, and user
CSS (`~/.config/gtk-4.0/gtk.css`) wins over app/theme CSS. Ghostty implements
`background-opacity < 1` by removing its `.background` class from the window
(`syncAppearance` in `src/apprt/gtk/class/window.zig`), expecting the window
background to go transparent. Our rule painted the `window` node opaque
regardless of that class, so:

1. GDK computed a **full-surface opaque region** from the opaque CSS background.
2. Hyprland honored it: `CWindow::opaque() == true` → the surface was composited
   with alpha forced to 1 and the blur pass was skipped (`shouldBlur`).
3. Ghostty's 50%-alpha background was blended by GTK against the opaque window
   backdrop → "lighter, never transparent".

The compositor was never at fault; it was being told the surface was opaque.

## Investigation summary

- `hyprctl getprop`: window `opacity=1`, `opaque=false` — window-level alpha was
  not the issue.
- `WAYLAND_DEBUG`: ghostty's buffer is ARGB8888, and GDK sends
  `wl_surface.set_opaque_region` covering the full surface.
- Controlled GTK4 experiments (`/tmp/gtkalpha`): a plain window with
  `background-color: transparent` lets GL-area content (40% alpha) reach the
  compositor; the same window with an opaque CSS background is solid.
- Isolation test: ghostty was transparent with the custom `gtk.css` disabled,
  solid with it enabled — causality proven in both directions.
- Fix candidate `ghosttywindow { background-color: transparent }` did **not**
  match (ghostty's window inherits the GTK `window` css name), so selectors
  must be class-based, not type-name-based.

## The fix

In `modules/theme.nix`, scope the background paint to windows that self-declare
the `.background` class (the GTK convention) instead of every `window`:

```diff
- window, .background {
+ window {
+   color: @theme_fg_color;
+ }
+ window.background, .background {
    background-color: @theme_bg_color;
    color: @theme_fg_color;
  }
```

Why this is safe:

- Ghostty adds `.background` to its window **only when opaque**
  (`background-opacity >= 1`); when transparent it removes the class, so the
  rule stops matching and the surface alpha reaches the compositor (blur works).
- GTK3 apps are unaffected: their root window always carries `.background`.
- Apps with no `.background` class fall back to the theme's own window
  background (still dark under the dark theme) instead of the exact `#0a1e24`.

## Prevention

When adding rules to the generated GTK CSS:

- Do **not** paint an opaque `background-color` on a bare type selector like
  `window` or `headerbar`-level root nodes that apps rely on for transparency.
- Prefer class-scoped selectors (`.background`, or app-specific classes) so apps
  that toggle their own background class keep control.
- Treat `.background` as the contract: "this node has a background". Opaque
  windows carry it; transparency-seeking windows (ghostty) remove it.
- If a GTK app's transparency breaks, check whether a user-priority rule paints
  its window background before looking at the compositor.
- Remember user CSS beats both the theme and the app, so a broad rule is final.

## Verification

```sh
# launch a translucent ghostty and check for wallpaper + frosted blur
ghostty --config-file=/tmp/transp-test/config   # opacity 0.4, blur 20
# pixel-level check (region must contain wallpaper structure, not uniform):
grim -g WxH+X+Y /tmp/shot.png
# wallpaper structure present  => alpha flowing
# uniform color                => opaque region still being set
```

## Follow-up: the otter-launcher window stayed opaque

After the fix, the otter-launcher window was still solid while every other ghostty
window was transparent. The launcher runs inside a **persistent ghostty
single-instance server** started at login
(`ghostty --class=com.otter.launcher --initial-window=false ...`, in
`modules/hyprland.nix`). GTK loads the user gtk.css **once per process at
startup**, so that server had the old opaque CSS cached in memory and every
launcher window it spawned rendered opaque — a stale-state artifact, not a new
bug.

Lesson: after changing the generated GTK CSS, any **long-lived GTK process**
started before the change must be restarted to pick it up. For the launcher:

```sh
pkill -f -- "class=com.otter.launcher"
ghostty --class=com.otter.launcher --initial-window=false \
  --quit-after-last-window-closed=false --gtk-single-instance=true &
```

(on next login `hyprland.nix` starts it fresh anyway). The otter-launcher
binary itself (`otter-launcher 0.7.6`) is a plain Rust/C process and is
irrelevant to CSS; its window is the ghostty window it runs inside.

## Follow-up: waybar workspace numbers rendered uniform white (2026-08-11)

A second leak from the same generated GTK CSS hit waybar on the same day.

**Symptom:** the workspace numbers (1 2 3) in waybar were all the same
near-white (`#ddeedd`), with no active/inactive distinction, and survived full
waybar restarts. Every other module (clock, network, cpu, ...) kept its correct
pill background, border and green accent text.

**Root cause:** the generated gtk.css contained `label { color:
@theme_fg_color; }`. Waybar is a GTK3 app, so it loads
`~/.config/gtk-3.0/gtk.css` as user-priority CSS and that rule directly matched
every `label` node in the bar. Waybar colors its workspace numbers through the
*button* ancestor — `#workspaces button { color: @theme_muted; }` and
`#workspaces button.active { color: @theme_accent; }` — and the number label
inherits from the button. But a **direct** declaration on the label always beats
an **inherited** value, regardless of specificity or provider priority. So every
number rendered `@theme_fg_color` and the `.active` class had no visible effect.
Other modules were unaffected because their labels are targeted directly by ID
(`#clock { color: @theme_accent; }`), and an ID selector (1,0,0) beats the type
selector `label` (0,0,1).

**Resolution (2026-08-11):** the generated GTK CSS was drastically scaled back
to **palette-only**. All element rules were removed (`window`,
`window.background`, `headerbar`/`.titlebar`, `label`, `selection`, `scrollbar`,
`.drag`). The file keeps only the `@define-color` palette that apps read; GTK
apps now pick their own element styling (Adwaita dark, via `settings.ini`
`gtk-application-prefer-dark-theme=1`). The removed `.drag` rules were ripdrag's
themed drag pill; ripdrag now uses the Adwaita-dark default.

**The rule from now on:** this file is user-priority CSS loaded by every
GTK3/GTK4 app. A `@define-color` is inert, but a *rule* is a promise applied to
whatever nodes match — in any app. If an app needs restyling, do it in that
app's own config, never here.

## Files

| File | Role |
| --- | --- |
| `modules/display/theme.nix` | Generates `~/.config/gtk-{3,4}.0/gtk.css` (palette-only since 2026-08-11) |
| `~/.config/gtk-4.0/gtk.css` | Live symlink into `.local/share/theme/generated/gtk/colors.css` |
| `modules/_assets/ghostty-transparency.md` | This postmortem (tracked copy; live source `/etc/nixos/assets/ghostty-transparency.md`) |
