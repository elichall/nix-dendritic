# Neovim Nixification: Framework Evaluation

Should this repository migrate from pure Lua dotfiles to a Nix-native
Neovim framework? This report evaluates Nixvim, NVF, NixCat's, and the
bare `programs.neovim` baseline against the current architecture.

**Status**: ANALYSIS — no changes recommended or implemented.

---

## 1. Current Architecture

The existing setup at `modules/programs/nvim.nix` + `_assets/dotfiles/nvim/`
uses:

- **lazy.nvim** bootstrapped in `init.lua`, plugin specs in `lua/lean/plugins/*.lua`
- **LSP servers** (8 total) installed via `home.packages` in nixpkgs
- **Spell expansion** as a custom `mkDerivation` build step (inflection expansion
  + mkspell compilation)
- **xdg.configFile** to symlink the entire `_assets/dotfiles/nvim` tree into
  `~/.config/nvim`
- **lean_sync colorscheme** that reads the theme engine's palette from
  `~/.config/nvim/lua/lean/core/palette.lua` (symlinked at runtime by `sync-ghostty`)
- **blink.cmp** for completion with custom sources (spell, bibtex planned)
- Full Lua authoring: all config is hand-written `.lua` files with lazy.nvim
  plugin specs

### What's Nix-managed today

| Concern | Nix role | Lua role |
|---------|----------|----------|
| Plugin installation | ❌ lazy.nvim downloads from GitHub at runtime | lazy.nvim spec tables |
| Plugin config | ❌ | ✅ Full Lua setup calls |
| LSP binaries | ✅ `home.packages` | ✅ `lspconfig` setup in `lsp.lua` |
| Treesitter grammars | ✅ `tree-sitter` package in `home.packages` | ✅ `nvim-treesitter` config |
| Spell expansion | ✅ Custom `mkDerivation` | ✅ Reads `.expanded` at runtime |
| Colorscheme | ✅ `sync-ghostty` generates `palette.lua` | ✅ `lean_sync.lua` reads it |
| Editor variables | ✅ `home.sessionVariables` (EDITOR, etc.) | ❌ |

### What's NOT Nix-managed

- Plugin versions (lazy.nvim lockfile, not `flake.lock`)
- Plugin source pins (no hash pinning — lazy.nvim fetches latest)
- Lazy-loading strategy (lazy.nvim's event/cmd/ft triggers)
- Lua configuration (pure authoring)

---

## 2. Framework Profiles

### 2a. Nixvim

| Attribute | Detail |
|-----------|--------|
| **Repo** | `github:nix-community/nixvim` |
| **Stars** | 2,900 |
| **Philosophy** | "Nix for everything" — every option is a Nix module |
| **Output** | Wrapped `neovim-unwrapped` with generated `init.lua` baked in |
| **Plugin source** | `pkgs.vimPlugins` from nixpkgs (or `extraPlugins` for custom) |
| **Lazy loading** | `lz-n` (preferred) or lazy.nvim (optional) |
| **LSP** | `lsp.servers.<name>.settings.*` — typed Nix options per server |
| **Lua interop** | `extraConfigLua`, `__raw` for function values, `extraFiles` |
| **HM module** | ✅ `programs.nvim` — mutual exclusion with `programs.neovim` |
| **flake-parts** | Works via HM module; `inputs` via `specialArgs` |
| **Store output** | Single wrapped nvim binary, all plugins on rtp |
| **Startup** | Near-native with `wrapRc = true` + `byteCompileLua` |
| **Stability** | Version-mismatch warnings; `follows` on nixpkgs discouraged |

**Configuration style (telescope example):**

```nix
# Nix — generates require('telescope').setup({...})
plugins.telescope = {
  enable = true;
  settings.defaults.file_ignore_patterns = [ "node_modules" "%.git/" ];
};
keymaps = [
  { mode = "n"; key = "<leader>ff"; action = "<cmd>Telescope find_files<CR>"; }
];
```

vs. current Lua:

```lua
-- Raw Lua — direct, no translation layer
require("mini.pick").setup({ options = { use_cache = true } })
vim.keymap.set("n", "<leader>f", function() MiniPick.builtin.files() end)
```

### 2b. NVF

| Attribute | Detail |
|-----------|--------|
| **Repo** | `github:NotAShelf/nvf` |
| **Stars** | 1,600 |
| **Philosophy** | "Lua-first, Nix-optional" — hybrid wrapper |
| **Output** | Wrapped nvim via `mnw` (Minimal Neovim Wrapper) |
| **Plugin source** | npins (GitHub pins) or `pkgs.vimPlugins` |
| **Lazy loading** | `lz.n` (first-class since v0.7) |
| **LSP** | `vim.lsp.servers` — mirrors Neovim 0.11 `vim.lsp.config` API |
| **Lua interop** | DAG system for ordering; `mkLuaInline`; `additionalRuntimePaths` for ~/.config/nvim |
| **HM module** | ✅ `programs.nvf` |
| **flake-parts** | Works via HM module or standalone `neovimConfiguration` |
| **Store output** | Wrapped nvim binary via mnw |
| **Startup** | Fast (lz.n is minimal) |
| **Stability** | Tagged releases, backport branches |

**Unique feature — DAG ordering:**

```nix
vim.luaConfigRC.myConfig = lib.nvim.dag.entryAfter ["globalsScript"] ''
  vim.o.tabstop = 4
'';
```

Ensures config ordering without fragile string concatenation.

**Hybrid escape hatch:**

```nix
vim.additionalRuntimePaths = [ "~/.config/nvim" ];
```

Load an existing Lua config alongside Nix-managed plugins.

### 2c. NixCat's

| Attribute | Detail |
|-----------|--------|
| **Repo** | `github:BirdeeHub/nixCats-nvim` |
| **Stars** | 699 |
| **Status** | ⚠️ **Maintenance mode** — successor is `nix-wrapper-modules` |
| **Philosophy** | "Nix is for downloading. Lua is for configuring." |
| **Output** | Wrapped nvim with `nixCats` Lua bridge module |
| **Plugin source** | `pkgs.vimPlugins` + flake inputs with `plugins-` prefix |
| **Lazy loading** | `lze` or `lz.n` (recommended over lazy.nvim) |
| **LSP** | Manual `lspconfig` setup in Lua (Nix only installs binaries) |
| **Lua interop** | **Best in class** — `nixCats()` function returns Nix data as Lua tables |
| **HM module** | ✅ `homeModules.default` |
| **Store output** | Wrapped nvim binary |
| **Startup** | Fast (3x faster than Nixvim reported by some users) |
| **Stability** | Maintenance mode; templates may be deleted |

**The Nix↔Lua bridge:**

```nix
-- Nix: pass arbitrary data
categories = { lspDebugMode = true; theBestCat = "says meow!"; };
```

```lua
-- Lua: read it as native tables
if nixCats("lspDebugMode") then vim.lsp.set_log_level("debug") end
local msg = nixCats("theBestCat")  -- "says meow!"
```

### 2d. Bare `programs.neovim` / `pkgs.wrapNeovim`

| Attribute | Detail |
|-----------|--------|
| **Source** | nixpkgs + Home Manager built-in |
| **Philosophy** | Nix wraps, you configure |
| **Output** | Wrapped nvim via `wrapNeovimUnstable` |
| **Plugin source** | `pkgs.vimPlugins` via `plugins = [ ... ]` |
| **Lazy loading** | None natively — all `start/` plugins load at boot |
| **LSP** | Manual: add to `extraPackages`, configure in `extraLuaConfig` |
| **Lua interop** | Full — `extraLuaConfig` is raw Lua injection |
| **HM module** | ✅ `programs.neovim` (built-in) |
| **Store output** | Wrapped nvim binary |

**This is closest to what you already have** — except you currently bypass
`programs.neovim` entirely and use `xdg.configFile` + lazy.nvim download.

---

## 3. Comparative Matrix

| Criterion | Current (dotfiles) | Nixvim | NVF | NixCat's | Bare HM |
|-----------|-------------------|--------|-----|----------|---------|
| **Plugin version pinning** | ❌ lazy lockfile only | ⚠️ tracks nixpkgs | ✅ npins per-plugin | ✅ nixpkgs or flake inputs | ❌ user-managed |
| **Plugin source reproducibility** | ❌ runtime fetch | ✅ store paths | ✅ store paths | ✅ store paths | ✅ store paths |
| **Lua authoring comfort** | ✅ native .lua files | ❌ Nix strings → Lua | ⚠️ DAG + inline Lua | ✅ native .lua files | ✅ extraLuaConfig |
| **LSP declarative config** | ❌ manual lspconfig | ✅ typed options | ✅ typed options | ❌ manual lspconfig | ❌ manual lspconfig |
| **Lazy loading** | ✅ lazy.nvim | ⚠️ lz-n (experimental) | ✅ lz.n (first-class) | ✅ lze/lz.n | ❌ none |
| **Custom spell expansion** | ✅ mkDerivation | ⚠️ extraFiles + Lua | ⚠️ DAG entry | ✅ Lua reads from store | ✅ extraLuaConfig |
| **Theme engine integration** | ✅ palette.lua symlink | ❌ would need extraFiles | ⚠️ DAG entry | ⚠️ nixCats.extra | ✅ rtp includes |
| **Standalone .lua editing** | ✅ direct file edit | ❌ must edit Nix | ⚠️ additionalRuntimePaths | ✅ wrapRc=false mode | ✅ direct file edit |
| **Dendritic architecture fit** | ✅ xdg.configFile | ⚠️ needs HM import | ⚠️ needs HM import | ⚠️ needs HM import | ✅ programs.neovim |
| **Nix-level validation** | ❌ runtime errors only | ✅ option types | ✅ option types | ❌ runtime only | ❌ runtime only |
| **Migration effort** | — | 🔴 High | 🟡 Medium | 🟢 Low | 🟢 Very Low |
| **Community size** | — | 2.9k ⭐ | 1.6k ⭐ | 699 ⭐ (maintenance) | built-in |
| **Startup time** | ✅ fast (lazy.nvim) | ⚠️ slower w/ many plugins | ✅ fast (lz.n) | ✅ fast | ✅ fastest |
| **Store footprint** | small (dotfiles only) | large (all plugins in store) | large | large | large |

---

## 4. Deep Analysis: Key Criteria

### 4a. Plugin Management & Reproducibility

**Current gap**: lazy.nvim fetches plugins from GitHub at runtime. The lockfile
pins revisions, but there's no Nix-level hash. A `nixos-rebuild` doesn't update
plugin versions; only `nvim --headless "+Lazy update"` does. This means:
- Plugin versions drift between rebuilds
- No `nix flake lock --update-input` control over plugin pins
- Network access required on first launch or after lockfile changes

**Framework advantage**: All three frameworks install plugins as Nix store
derivations. Plugin versions track `flake.lock` (via nixpkgs or direct pins).
No runtime network access. Full reproducibility.

**However**: Your current setup works. Lazy.nvim's lockfile is battle-tested
and the drift is minimal in practice. The reproducibility gain is real but
not urgent.

### 4b. LSP Configuration

**Current approach**: 8 LSP servers in `home.packages` + manual `lspconfig`
setup in `lsp.lua` with custom configs (texlab build args, ltex-ls dictionary
loading, clangd query-driver glob). This is ~145 lines of Lua.

**Nixvim/NVF approach**: Declarative `lsp.servers.*` with typed settings.
But your `load_scientific_dictionary()` function (reads `.expanded` file,
parses words, returns Lua table) cannot be expressed as a Nix attrset — it
requires `__raw` or `mkLuaInline`. The custom `clangd` cmd with
`--query-driver=/nix/store/*/bin/*g++` glob is also Nix-unfriendly.

**Verdict**: LSP configuration would NOT simplify. Your custom server
configs are too dynamic for declarative Nix options. You'd end up writing
the same Lua via `__raw` strings — just with extra indirection.

### 4c. Spell Expansion Derivation

**Current approach**: A `mkDerivation` in `nvim.nix` that:
1. Reads the base wordlist
2. Generates inflection expansions (plurals, possessives) in pure Nix
3. Compiles `.spl` via headless nvim at build time

**Framework compatibility**: This is already pure Nix. All frameworks can
consume the output via `extraFiles`, `extraConfigLua`, or equivalent. The
derivation itself wouldn't change — only how it's wired into the config.

**NVF** has the cleanest integration via its DAG system. **NixCat's** can
pass the path via `nixCats.extra()`. **Nixvim** would use `extraFiles`.
**Bare HM** uses `xdg.configFile` (your current method).

None of these are meaningfully better than what you have.

### 4d. Theme Engine Integration

**Current approach**: `sync-ghostty` generates `palette.lua` into
`~/.config/nvim/lua/lean/core/palette.lua`. The `lean_sync` colorscheme
reads it via `require("lean.core.palette")`.

**Framework impact**: This runtime-generated file must remain in the rtp.
- **Nixvim**: Would need `impureRtp = true` (include `~/.config/nvim` in rtp)
  or `extraFiles` pointing to the generated path. But `extraFiles` is
  build-time — the palette doesn't exist at build time.
- **NVF**: `vim.additionalRuntimePaths = [ "~/.config/nvim" ]` handles this.
- **NixCat's**: `wrapRc = false` reads from `~/.config/<dir>` — works.
- **Bare HM**: Your current approach works.

**Verdict**: The runtime-generated palette is architecturally incompatible
with fully hermetic Nix configs. You need an impure rtp entry, which all
frameworks support but none handle more cleanly than your current
`xdg.configFile` approach.

### 4e. Lua Authoring Experience

**This is the critical criterion.**

| Framework | Where Lua lives | IDE support | Edit cycle |
|-----------|----------------|-------------|------------|
| **Current** | `.lua` files in `_assets/dotfiles/nvim/` | ✅ Full (nvim LSP for Lua) | Edit file → restart nvim |
| **Nixvim** | Inside Nix strings (`extraConfigLua = ''...''`) | ❌ No LSP in Nix strings | Edit .nix → nix build → test |
| **NVF** | DAG entries + `mkLuaInline` | ⚠️ Partial (DAG entries are strings) | Edit .nix → nix build → test |
| **NixCat's** | `.lua` files (same as current) | ✅ Full | Edit file → rebuild |
| **Bare HM** | `extraLuaConfig` string | ❌ No LSP in Nix strings | Edit .nix → nix build → test |

**Nixvim and NVF require translating Lua logic into Nix attrsets.** Your
existing config has:
- 117-line `lean_sync.lua` colorscheme with dynamic palette loading
- 145-line `lsp.lua` with conditional server configs and custom functions
- 75-line `completion.lua` with per-filetype source routing
- 42-line `keymaps.lua` with leader-key mappings
- Custom spell expansion Lua that reads build artifacts

All of this would need to be either:
1. Translated to Nix options (where supported) + `__raw` strings (where not)
2. Kept as raw Lua via escape hatches (defeating the purpose of Nixification)

**NixCat's and bare HM preserve your Lua authoring experience.** The Lua
files stay as `.lua` files. Nix only manages packages and paths.

### 4f. Startup Time

| Approach | Mechanism | Expected startup |
|----------|-----------|-----------------|
| **Current** | lazy.nvim (runtime fetch, ~15 plugins) | ~50-80ms |
| **Nixvim** | Generated init.lua, all plugins on rtp | ~80-150ms (no lazy loading by default) |
| **NVF** | lz.n lazy loading, mnw wrapper | ~40-70ms |
| **NixCat's** | lze lazy loading, store-path plugins | ~40-60ms |
| **Bare HM** | pack/start/ all load at boot | ~100-200ms (no lazy loading) |

Your current lazy.nvim setup with event/cmd/ft triggers is already
well-optimized. Nixvim without lazy loading would be a regression.
NVF and NixCat's with lz.n/lze would be comparable or slightly better.

### 4g. Migration Effort

| Framework | Estimated effort | What changes |
|-----------|-----------------|--------------|
| **Nixvim** | 🔴 3-5 days | Rewrite all plugin specs as Nix attrsets, translate Lua config, rewire LSP, test theme integration, handle spell derivation, update contracts |
| **NVF** | 🟡 2-3 days | Similar to Nixvim but DAG system helps ordering; Lua interop is better |
| **NixCat's** | 🟢 1 day | Keep Lua files, add categoryDefinitions + packageDefinitions, wire lazy loading via lze, add Nix plugin pins |
| **Bare HM** | 🟢 0.5 day | Replace lazy.nvim with `programs.neovim.plugins`, move LSP to `extraPackages`, accept loss of lazy loading |

---

## 5. Cost-Benefit Assessment

### What Nix-native frameworks actually buy you

| Benefit | Real value? | Notes |
|---------|------------|-------|
| Plugin version pinning in flake.lock | ⚠️ Marginal | lazy.nvim lockfile works; drift is minimal |
| Reproducible builds | ⚠️ Marginal | Your dotfiles are already tracked in git |
| Nix-level type validation | ⚠️ Marginal | Lua errors surface at nvim startup; Nix errors at build time — both are caught |
| Declarative LSP config | ❌ Not for your setup | Your custom configs (ltex dictionary, clangd glob) require Lua anyway |
| Lazy loading control | ⚠️ Marginal | lazy.nvim already does this well |
| Single `nixos-rebuild` to update everything | ❌ Not true | Plugin updates still need separate steps in all frameworks |
| Reproducible across machines | ⚠️ Marginal | `nix run` works but you edit on one machine |

### What Nix-native frameworks cost you

| Cost | Severity | Notes |
|------|----------|-------|
| **Lua authoring displacement** | 🔴 High | All config moves from `.lua` to `.nix` strings (Nixvim/NVF) or requires wrapper plumbing (NixCat's) |
| **Edit-cycle friction** | 🔴 High | Edit .nix → `nix build` → test (vs. edit .lua → restart nvim) |
| **Framework coupling** | 🟡 Medium | Your config becomes dependent on framework API; updates can break |
| **Nix evaluation overhead** | 🟡 Medium | Large module trees slow `nix eval`; your 145-line `lsp.lua` becomes ~200 lines of Nix |
| **Debugging opacity** | 🟡 Medium | Errors trace through framework internals; stack traces are harder to read |
| **Theme engine incompatibility** | 🟡 Medium | Runtime-generated `palette.lua` requires impure rtp — fights hermetic design |
| **Dendritic architecture friction** | 🟡 Medium | Frameworks want to own `programs.nvim` or `programs.nvf`; your module system uses `xdg.configFile` + `home.packages` |
| **Migration time** | 🟡 Medium | 0.5-5 days depending on framework |
| **Upstream lag** | 🟠 Low-Med | New plugin features wait for framework module updates |

---

## 6. Verdict

### Is it worth doing?

**No — not for this configuration.**

Your Neovim setup is **Lua-native by design**. The config files are well-structured
(`lean/plugins/*.lua`), the theme integration is runtime-driven, the LSP
configuration is highly custom, and the edit cycle (edit .lua → restart) is
fast and frictionless. The things Nix frameworks optimize — plugin source
reproducibility and declarative configuration — are already handled well enough
by lazy.nvim + nixpkgs `home.packages`.

The fundamental mismatch: **your config's complexity lives in Lua logic
(conditional LSP configs, dynamic palette loading, spell expansion,
per-filetype completion routing) — not in plugin option declarations.**
Nix frameworks are designed to express "which plugins, with what options" —
they don't help with "how does the spell expansion derivation feed into
the LSP dictionary at runtime."

### When WOULD it be worth it?

1. **If you were starting from scratch** with a simpler config (basic LSP,
   standard plugin options, no runtime-generated artifacts) — Nixvim or NVF
   would give you a clean, reproducible setup with less boilerplate.

2. **If you wanted `nix run github:user/repo` portability** — a framework
   makes your Neovim config a flake output that works on any Nix machine.
   NixCat's does this with the least friction.

3. **If you wanted to eliminate lazy.nvim** entirely — NixCat's or bare HM
   with `pkgs.vimPlugins` would replace lazy.nvim's runtime downloads with
   store-path plugins. This removes one network-dependent component.

4. **If you were building a multi-host config** (workstation + WSL + server)
   where Neovim config should vary by host flags — frameworks make this
   a Nix module system problem (which you already solve well).

### If you still want partial Nixification

The lightest touch that gains real value:

- **Keep your Lua dotfiles as-is**
- **Add plugin source pins to flake inputs** (like you did for `wlctl` and
  `otter-launcher`) for the ~5 critical plugins (blink.cmp, obsidian.nvim,
  mini.pick, oil.nvim, vim-tmux-navigator)
- **Use `pkgs.vimUtils.buildVimPlugin`** for non-nixpkgs plugins
- **Move LSP server packages into a dedicated `home.packages` block**
  (already done)

This gives you flake.lock reproducibility for plugin sources without
rewriting any Lua config. It's the nixCats philosophy without the framework.

---

## 7. Recommendation Summary

| Action | Verdict |
|--------|---------|
| Migrate to Nixvim | ❌ Not recommended — Lua displacement cost too high |
| Migrate to NVF | ❌ Not recommended — DAG system is elegant but unnecessary |
| Migrate to NixCat's | ⚠️ Possible but not urgent — lowest friction if you want framework benefits |
| Migrate to bare HM | ❌ Regression — loses lazy.nvim lazy loading |
| Add plugin pins to flake inputs | ✅ Recommended — gains reproducibility without rewrite |
| Keep current architecture | ✅ **Recommended** — your setup is well-designed for its goals |

The current Lua dotfile approach is **the right architecture for a config this
complex**. The theme engine integration, custom spell derivation, and dynamic
LSP configs are all things that work best as runtime Lua, not build-time Nix.
A framework would add abstraction without reducing complexity.
