# Research Aspect Group

Terminal-centric research workflow: Obsidian vaults, Zotero bibliography, Pandoc
compilation, and Neovim integration. Everything is user-scale (home-manager only,
no NixOS-level changes).

## Enabling

Import `homeManager.researchGroup` in your host's user imports:

```nix
home-manager.users.elichall.imports = [
  # ...
  self.modules.homeManager.researchGroup
  # ...
];
```

The group aggregates three modules:

| Module | Key | What it provides |
|--------|-----|------------------|
| `research` | `homeManager.research` | pandoc + texlive (user-scale) |
| `obsidian` | `homeManager.obsidian` | nvim plugin layer for Obsidian vaults |
| `zotero` | `homeManager.zotero` | Flatpak desktop entry |

Individual keys are importable standalone if you only need part of the stack.

---

## Modules

### 1. `research` — Pandoc + TeX Live

**What's installed:**
- `pandoc` with citeproc enabled and xelatex as default PDF engine
- Slim texlive: latexmk, biber, bibtex, collection-latex, xetex, fontspec,
  unicode-math, amsmath, geometry, hyperref, graphics, fancyhdr, titlesec,
  xcolor, listings, fancyvrb, booktabs, mdwtools

**What's NOT installed:** No vimtex, no large collections (~30-50MB store cost).

#### Usage

```bash
# Markdown → PDF (with citations)
pandoc paper.md --bibliography references.bib -o paper.pdf

# Markdown → DOCX
pandoc paper.md -o paper.docx

# Markdown → PDF (with page numbers, custom title)
pandoc paper.md --bibliography references.bib \
  --pdf-engine=xelatex \
  -V geometry:margin=1in \
  -o paper.pdf

# Process bibliography only (check biber output)
biber paper

# Build with latexmk (for vimtex users)
latexmk -pdf paper.tex
```

**Default pandoc behavior:** citeproc is always on, xelatex is the engine, 1in
margins. Override with `--pdf-engine=...` or `-V` flags.

#### Adding packages

If a document needs a LaTeX package not in the slim set, add it to
`modules/research/default.nix`:

```nix
extraPackages = tpkgs: {
  inherit (tpkgs)
    # ... existing packages ...
    newpackage  # add here
    ;
};
```

---

### 2. `obsidian` — Neovim Vault Integration

**What's installed (lazy.nvim plugins):**
- `obsidian-nvim/obsidian.nvim` — vault navigation, backlinks, daily notes,
  wiki-links, LSP integration
- `krissen/blink-cmp-bibtex` — BibTeX citation completion for blink.cmp
- `saghen/blink.cmp` — bibtex source merged via lazy.nvim deep-merge
- `obsidian_ls` LSP server — link resolution, rename-with-link-update

**What's NOT installed:** This is nvim-only. Obsidian itself is managed
separately (flatpak). The nvim plugin layer works independently.

#### Architecture

The base nvim config deploys via `xdg.configFile."nvim"` (store symlink).
Feature modules generate Lua files into `lean/research/` and merge them via a
`home.activation` hook that resolves the symlink, copies the directory, and
layers feature files on top. See `decisions.md` #34 and `module-contracts.md`
C21 for rationale.

When this module is NOT imported, no research files exist in the nvim config —
zero plugins, zero LSPs, zero cost.

#### Workspaces

Configured in the generated `init.lua`:
- `me` → `~/Documents/me/vault` (full vault root)
- `test` → `~/Documents/test`

To add a workspace, edit `vaultPath` and the workspaces list in
`modules/research/obsidian.nix`.

#### Keybindings

| Key | Command | Description |
|-----|---------|-------------|
| `gl` | `:Obsidian follow_link` | Follow wiki-link under cursor |
| `[o` | `:Obsidian nav_link prev` | Jump to previous link in buffer |
| `]o` | `:Obsidian nav_link next` | Jump to next link in buffer |
| `<leader>nt` | `:ObsidianTemplate` | Insert template from `.templates/` |

`<CR>` triggers obsidian.nvim's default `smart_action` (open link, toggle
checkbox) — this is an implicit default, not explicitly configured.

#### Templates

Templates live in `vault/.templates/` (7 archetypes: paper, experiment,
concept, project, report, daily, moc). Insert via `<leader>nt` or
`:ObsidianTemplate`. Variables `{{date}}` and `{{time}}` are substituted
on insertion.

**Commands** (with `legacy_commands = false`):

| Command | Description |
|---------|-------------|
| `:Obsidian quick_switch` | Find files in vault |
| `:Obsidian search` | Grep across vault content |
| `:Obsidian backlinks` | Show backlinks for current note |
| `:Obsidian open` | Open note in Obsidian app (vault must be registered) |
| `:Obsidian toggle_checkbox` | Toggle `- [ ]` / `- [x]` |
| `:Obsidian new <name>` | Create note in vault root |
| `:Obsidian today` | Open/create today's daily note |
| `:Obsidian template` | Insert from templates folder |

#### BibTeX Completion

In markdown/tex/plaintex files, type `@` then start typing a citekey:
- `@knuth` → shows `knuth1984` with APA preview
- **Hierarchical discovery**: `.bib` files are found by walking up from the
  buffer's directory to the vault root, collecting `*.bib` at each level.
  A note in `research/papers/sph/` sees its own `references.bib` plus
  ancestors up to `vault/`, but NOT siblings like `class/`.
- Multiple `.bib` files are merged and deduplicated
- Preview style: APA

#### LSP (obsidian-ls)

- `:LspInfo` in a markdown file → should show `obsidian-ls` attached
- Hover on `[[wiki-link]]` → resolves to target note
- Rename via LSP → propagates link updates across vault

#### UI

`ui.enable = false` — lean_sync colorscheme handles rendering. Obsidian's
conceal marks are disabled to avoid conflicts.

`picker = { name = "mini.pick" }` — forced explicitly (auto-detect failed).
Obsidian-specific pickers (backlinks, tags, toc) use mini.pick as well.

`frontmatter = { enabled = false }` — disables obsidian.nvim's auto-formatting
of YAML frontmatter on save. YAML is still read; it's just not auto-modified.

`checkbox = { create_new = false, order = { " ", "x" } }` — disables turning
normal paragraphs into checkboxes on Enter. Only two states (unchecked/checked)
instead of the default five.

---

### 3. `zotero` — Desktop Entry

Flatpak desktop entry for Zotero (`org.zotero.Zotero`). Wires the flatpak
into the application menu with proper MIME types for `.bib`, `.ris`, and
citation formats.

Zotero itself is installed via:
```bash
flatpak install flathub org.zotero.Zotero
```

#### Better BibTeX Setup (Manual)

1. In Zotero: Edit → Preferences → Plugins → Install Add-on From File
2. Download `better-bibtex.xpi` from
   https://retorque.re/zotero-better-bibtex/installation/
3. Restart Zotero
4. Edit → Preferences → Better BibTeX:
   - Enable "Keep updated" for auto-export
   - Export format: "Better BibLaTeX"
   - Set output directory to your vault's research folder

---

## Test Vault

A test vault exists at `~/Documents/test` for trying features in a controlled
environment:

```
~/Documents/test/
├── .obsidian/           # minimal Obsidian config
├── papers/
│   └── references.bib   # sample .bib with 4 entries
├── ideas/
│   └── scratch.md
├── daily/               # for daily notes
├── attachments/         # for images
├── Welcome.md           # start here
├── Citations.md         # citeproc test
├── Wiki Links.md        # link following test
├── Backlink Source.md   # backlink test
├── Backlink Target.md   # backlink test
├── Checkbox Test.md     # toggle test
└── Searchable Content.md # search test
```

Open with: `cd ~/Documents/test && nvim Welcome.md`

---

## Troubleshooting

**Pandoc: "unicode-math.sty not found"**
Add `unicode-math` to texlive extraPackages in `modules/research/default.nix`.

**Pandoc: "xelatex not found"**
Add `xetex` to texlive extraPackages.

**Nvim: research plugins not loading**
Check that `homeManager.researchGroup` (or `homeManager.obsidian`) is in your
host's user imports. Run `nvim --headless -c "lua print(pcall(require, 'lean.research'))" -c "qa!"`.

**Nvim: activation hook permission errors**
The activation hook resolves a store symlink and copies files. If permissions
break, run `sudo nixos-rebuild switch --flake ~/.nix#workstation` to re-trigger.

**BibTeX completion not showing**
`.bib` files are auto-discovered per buffer — walks up from the buffer's
directory to the vault root (`.obsidian/`), collecting `*.bib` at each level.
Ensure `.bib` files exist in the buffer's directory chain within a vault.
Check what the function resolves to for the current buffer:
`:lua print(vim.inspect(require('blink-cmp-bibtex.scan').resolve_bib_paths(0, require('blink-cmp-bibtex.config').get())))`.

---

## File Map

| File | Purpose |
|------|---------|
| `modules/research/default.nix` | pandoc + texlive config |
| `modules/research/obsidian.nix` | nvim plugin layer + activation hook |
| `modules/research/zotero.nix` | flatpak desktop entry |
| `modules/groups/research.nix` | group preset (aggregates above) |
| `_assets/plans/research_workflow_stack.md` | implementation plan |
| `_assets/documentation/module-contracts.md` | C20 (vault path), C21 (adaptive framework) |
| `_assets/documentation/decisions.md` | #34 (adaptive nvim), #35 (research group) |
