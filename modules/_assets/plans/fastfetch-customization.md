# Fastfetch Customization

> **STATUS: IMPLEMENTED (2026-08-12)** — `modules/programs/fastfetch.nix`.
> Logo renders `modules/_assets/nixos-image.png` as chafa block image
> (`logo.type = "chafa"`, `symbols = "block"`, width 40, tunable).
> `logo.height` is NOT set — the fastfetch schema accepts only `null` (auto,
> aspect-ratio-preserving default) or an integer ≥ 1; `0` errors with
> "Logo height must be a positive integer".
> NOTE (2026-08-12): `symbols = "block+semi"` was dropped — `semi` is NOT a
> valid chafa symbol tag (chafa 1.18.2 `parse_symbol_tag` table has no `semi`).
> fastfetch passed the string raw to `chafa_symbol_map_apply_selectors`, chafa
> rejected it, and fastfetch echoed "Unrecognized symbol tag 'semi'." to stderr
> (it continues rendering + caches the result, so the error only showed on a
> cold cache). `chafa.canvas = "full"` was also removed — not a schema key.
> fastfetch dlopens libchafa at runtime but ships it in its own closure, so no
> extra `home.packages` chafa entry is needed.
> NOTE (2026-08-12): an explicit `modules` list (= the default structure, per
> `fastfetch --print-structure`) was added. In fastfetch 2.63.1 a loaded config
> file with no `modules` key prints ONLY the logo — no default-structure
> fallback (`src/common/impl/jsonconfig.c`, `printJsonConfig` returns NULL when
> the root has no `modules` key).

I want to change the defaults of fastfetch to use chafa block images for the nixos logo instead of the default logo.

Other changes can be looked into.
