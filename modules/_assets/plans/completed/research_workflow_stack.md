# Research Workflow Stack

Terminal-centric research pipeline: Neovim as primary editor for an
Obsidian vault, Zotero/Better BibTeX for bibliography, Pandoc for
markdown-to-.docx/pdf compilation with built-in citeproc. Vault lives at
`~/Documents/me/vault`.

**Status**: IMPLEMENTED — all modules wired, adaptive nvim framework active,
bibtex trigger + auto-discovery working, keymaps configured.

### Implementation notes

- **texlive slimmed**: only pandoc template deps (geometry, hyperref,
  graphics, longtable, fancyhdr, titlesec, xcolor, listings, fancyvrb,
  fontspec, unicode-math, amsmath) + collection-latex + latexmk + biber
  + bibtex + xetex + booktabs + mdwtools. ~30-50MB store cost.
- **biber included**: user exports BibLaTeX format from Zotero, needs
  biber (not just bibtex).
- **Adaptive nvim framework** (decision #34, contract C21): feature modules
  generate Lua files → activation-merged into nvim config. Base uses
  pcall for graceful degradation.
- **Research group** (`homeManager.researchGroup`): aggregates research,
  obsidian, zotero. Separate from toolbox (core dev) and desktop (display).
- **File locations**: `modules/research/default.nix` (pandoc/texlive),
  `modules/research/obsidian.nix` (nvim integration + activation hook),
  `modules/research/zotero.nix` (flatpak desktop entry).
- **Canonical bib naming**: `references.bib` (not `.references.bib`).
  Build artifacts redirected to `.build/` via latexmk.

---

## 1. Architecture

| Layer | Tool | Role |
|-------|------|------|
| **Storage** | Obsidian vault (`~/Documents/me/vault/`) | Flat markdown files; Obsidian app as secondary visual canvas |
| **Editor** | Neovim + obsidian.nvim | Primary editing interface; in-process LSP for wiki-link completion, backlinks, rename |
| **Bibliography** | Zotero + Better BibTeX → `.bib` files | Citation key database; hierarchical per-domain `.references.bib` files |
| **Citation completion** | blink-cmp-bibtex | Native blink.cmp source; parses `.bib`, shows APA previews |
| **Compilation** | Pandoc (built-in citeproc) | Markdown → .docx/pdf with bibliography resolution |
| **LaTeX** | vimtex + texlive (latexmk/biber/bibtex) | LaTeX compilation for .tex files; pandoc PDF fallback |
| **Workspace** | Tmux + Ghostty | Splits editing buffer from compilation outputs |

### Data flow

```
Zotero ──Better BibTeX──▶ .bib files ──blink-cmp-bibtex──▶ @citekey autocomplete
                                                                    │
Obsidian vault ◀──obsidian.nvim── Neovim ──Pandoc keymap──▶ .docx output
```

---

## 2. Vault structure (post-restructuring)

The vault has been restructured with a 3-layer indexing system:

```
vault/
├── .templates/          # 7 archetype templates (paper, experiment, concept, project, report, daily, moc)
├── .obsidian/           # Config (templates.json → .templates/)
├── class/               # Coursework (e.g., class/26-summer/DBM/)
├── computer/            # System configs, hardening guides
├── daily/               # Daily notes
├── lab/CHAMP/           # AFSD lab experiment logs
├── projects/            # Active project plans and trackers
├── research/
│   ├── papers/          # Paper summaries by topic (sph/, constitutive-modeling/, residual-stress/)
│   ├── thesis/          # Thesis-specific concept notes
│   └── ideas/           # Seed-stage ideas
└── me.md                # Personal context document
```

**Key conventions:**
- All notes have mandatory YAML frontmatter (`id`, `title`, `type`, `tags`, `created`, `updated`)
- Faceted tags: `type/...`, `domain/...`, `status/...`, `material/...`, `method/...`
- Per-directory `references.bib` files with `@citekey` convention
- PDFs live in Zotero, not the vault
- Templates in `.templates/` (single directory, not scattered)
- **Canonical bib naming**: `references.bib` (not `.references.bib` — the
  hidden prefix was an earlier experiment, superseded by `.build/` artifact
  redirection)

---

## 3. Required nvim changes

Changes to `modules/research/obsidian.nix` (obsidian.nvim config):

### 3a. Expand workspace to vault root

**Current:**
```lua
workspaces = {
  { name = "research", path = "~/Documents/me/vault/research" },
  { name = "test", path = "~/Documents/test" },
},
```

**New:**
```lua
workspaces = {
  { name = "me", path = "~/Documents/me/vault" },
  { name = "test", path = "~/Documents/test" },
},
```

**Why:** MOCs, concept notes, class notes, daily notes, and projects all
live outside `research/`. Obsidian.nvim needs the vault root to resolve
wikilinks across the full graph.

### 3b. Add templates integration

Add `templates` option inside `opts`:
```lua
templates = {
  folder = ".templates",
  date_format = "%Y-%m-%d",
  time_format = "%H:%M",
},
```

Add keybinding inside `keys`:
```lua
{ "<leader>nt", "<cmd>ObsidianTemplate<cr>", desc = "Insert Template" },
```

### 3c. BibTeX discovery — hierarchical walk (function)

**Implemented:** `global_files` is a function that receives `bufnr` from
blink-cmp-bibtex per completion round. Walks up from buffer directory to vault
root (`.obsidian/`), collecting `*.bib` at each level. Each buffer only sees
`.bib` files in its directory chain up to the vault root.

```lua
local function discover_bib_files(bufnr)
  local ok, result = pcall(function()
    local bufname = bufnr and vim.api.nvim_buf_is_valid(bufnr)
      and vim.api.nvim_buf_get_name(bufnr) or ''
    if bufname == '' then return {} end
    local dir = vim.fn.fnamemodify(bufname, ':h')
    local bibs = {}
    local current = dir
    while current and current ~= '' and current ~= '/' do
      local matches = vim.fn.glob(current .. '/*.bib', false, true)
      for _, f in ipairs(matches) do
        bibs[#bibs + 1] = vim.fn.expand(f)
      end
      if vim.fn.isdirectory(current .. '/.obsidian') == 1 then
        break
      end
      current = vim.fn.fnamemodify(current, ':h')
    end
    return bibs
  end)
  if not ok then return {} end
  return result
end
```

**Why:** Hierarchical scoping matches the vault's conceptual hierarchy —
a note in `research/papers/sph/` should only see citekeys from its own
domain and parent directories, not from unrelated branches like `class/`.
Pass as function reference (`global_files = discover_bib_files`, not
`discover_bib_files()`) — blink-cmp-bibtex calls it via `pcall` per buffer.

---

## 4. Deferred changes

### 4a. Auto-update `updated` timestamp on save

Add `BufWritePre` autocmd to `lean/core/autocmds.lua`:
```lua
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.md",
  callback = function(args)
    local buf = args.buf
    local lines = vim.api.nvim_buf_get_lines(buf, 0, 2, false)
    if not lines[1] or lines[1] ~= "---" then return end
    local date = os.date("%Y-%m-%dT%H:%M:%S")
    local all_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    for i, line in ipairs(all_lines) do
      if i > 1 and line == "---" then break end
      if line:match("^updated:") then
        local row = i - 1
        vim.api.nvim_buf_set_lines(buf, row, row + 1, false, {
          "updated: " .. date
        })
        break
      end
    end
  end,
})
```

### 4b. LaTeX build artifact redirection (HIGH)

Redirect `.aux`, `.bbl`, `.blg`, etc. to `.build/` via
`latexmk -output-directory=.build` or `.latexmkrc`. Add `.build/`
to `.gitignore`. See `~/Documents/me/dev/plans/latex-build-redirection.md`.

### 4c. Pandoc compilation keymap (LOW)

A `<space>om` keymap for markdown → .docx compilation (see §9).

---

## 5. Existing infrastructure (already in place)

- Neovim: lazy.nvim, blink.cmp, 8 LSPs (nil, marksman, lua_ls, texlab, bashls, ltex, etc.)
- vimtex: LaTeX compilation + preview (`<leader>P` in tex files)
- md-view.nvim: markdown preview (`<leader>P` in markdown)
- ltex-ls: grammar + spelling for markdown/LaTeX (scientific dictionary, 621 expanded words)
- marksman: markdown LSP (headings, links)
- Zotero: flatpak desktop entry (`homeManager.zotero`)
- Tmux: full config with plugins
- Ghostty: terminal with theme integration

---

## 6. Dependency baggage

| Component | Deps Added | Conflict | Cost |
|-----------|-----------|----------|------|
| `pandoc` (HM module) | 1 derivation | None | ~50MB store |
| `texlive` (HM module) | latexmk + biber + bibtex + collection-latex + xetex + individual pkgs | None | ~30-50MB store |
| `obsidian.nvim` | `plenary.nvim` (light) | None — completion flows through LSP | Minimal |
| `blink-cmp-bibtex` | Pure Lua, zero external deps | None — native blink.cmp source | Zero |
| `obsidian_ls` | Provided by obsidian.nvim runtime | nvim-lspconfig has built-in config | Zero |

---

## 7. Manual setup steps (not automated)

1. **Better BibTeX in Zotero**: Install from
   https://retorquere.github.io/zotero-better-bibtex/installation/
   Then configure auto-export of collections to `.references.bib` files
   per domain directory.

2. **Corporate template** (optional): Generate base template with
   `pandoc -o corporate-template.docx --print-default-data-file reference.docx`,
   customize in Word, save to vault root. Reference via `--reference-doc=`.

3. **CSL style** (optional): Download a `.csl` file from
   https://www.zotero.org/styles and place in vault root.

---

## 8. Design decisions

| Decision | Rationale |
|----------|-----------|
| User-scale only (no nixos aspect) | All research tools are user binaries; no system-level consumer |
| `programs.pandoc` over bare `home.packages` | HM module provides `--defaults` injection, template management |
| obsidian.nvim with `ui.enable = false` | lean_sync colorscheme handles rendering; conceal marks would conflict |
| obsidian.nvim with `picker = "mini.pick"` | Auto-detect failed; forces mini.pick to avoid built-in native UI |
| `legacy_commands = false` | Uses new `:Obsidian <cmd>` API; silences deprecation warnings |
| Explicit `keys` for custom keymaps | Ensures `gl`/`[o`/`]o` work regardless of obsidian.nvim's autocmd setup |
| blink-cmp-bibtex trigger override | Pandoc matcher declares no trigger chars; override forces activation on `@` |
| BibTeX hierarchical walk (`global_files` function) | Per-buffer scoping: walks up from buffer dir to vault root (`.obsidian/`), collecting `*.bib` at each level |
| `attachments.folder` (not `img_folder`) | v4 renamed the option; `img_folder` is deprecated |
| No `follow_url_func` | Default `vim.ui.open` works; no need to override |
| blink-cmp-bibtex over cmp-zotero | Native blink.cmp source; parses .bib directly |
| `per_filetype` source list | `default = function(list)` pattern conflicts with obsidian.nvim's config iterator |
| `frontmatter = { enabled = false }` | Prevents auto-formatting YAML on save; community consensus |
| `checkbox = { create_new = false, order = { " ", "x" } }` | No paragraph→checkbox on Enter; 2 states only |
| texlive slim (1 collection + individual pkgs) | pandoc xelatex template deps only; ~30-50MB vs ~400-600MB full |
| `templates.folder = ".templates"` | Vault-wide templates (single directory, not scattered) |

---

## 9. Pandoc compilation keymap (future)

```lua
vim.keymap.set("n", "<leader>om", function()
  local file = vim.api.nvim_buf_get_name(0)
  local output = file:gsub("%.md$", ".docx")
  local bib_file = vim.fn.expand("~/Documents/me/vault/references.bib")
  local reference_doc = vim.fn.expand("~/Documents/me/vault/corporate-template.docx")

  local cmd = { "pandoc", file, "-o", output }
  if vim.fn.filereadable(bib_file) == 1 then
    table.insert(cmd, "--bibliography=" .. bib_file)
  end
  if vim.fn.filereadable(reference_doc) == 1 then
    table.insert(cmd, "--reference-doc=" .. reference_doc)
  end

  vim.fn.jobstart(cmd, {
    on_exit = function(_, code)
      if code == 0 then
        print("Word doc: " .. output)
      else
        print("Pandoc failed — check citations and paths")
      end
    end,
  })
end, { desc = "Compile Research Note to MS Word (.docx)" })
```
