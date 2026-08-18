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
  + bibtex + xetex. ~30-50MB store cost.
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

---

## 1. Architecture

| Layer | Tool | Role |
|-------|------|------|
| **Storage** | Obsidian vault (`~/Documents/me/vault/`) | Flat markdown files; Obsidian app as secondary visual canvas |
| **Editor** | Neovim + obsidian.nvim | Primary editing interface; in-process LSP for wiki-link completion, backlinks, rename |
| **Bibliography** | Zotero + Better BibTeX → `.bib` files | Citation key database; auto-discovered across vault |
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

## 2. Existing infrastructure (already in place)

- Neovim: lazy.nvim, blink.cmp, 8 LSPs (nil, marksman, lua_ls, texlab, bashls, ltex, etc.)
- vimtex: LaTeX compilation + preview (`<leader>P` in tex files)
- md-view.nvim: markdown preview (`<leader>P` in markdown)
- ltex-ls: grammar + spelling for markdown/LaTeX (scientific dictionary, 621 expanded words)
- marksman: markdown LSP (headings, links)
- Zotero: flatpak desktop entry (`homeManager.zotero`)
- Tmux: full config with plugins
- Ghostty: terminal with theme integration

---

## 3. Implementation (final state)

### 3a. `modules/research/default.nix`

`homeManager.research` module — user-scale pandoc + slim texlive. IMPLEMENTED.

```nix
{ ... }: {
  flake.modules.homeManager.research =
    { pkgs, ... }:
    {
      programs.pandoc = {
        enable = true;
        defaults = {
          citeproc = true;
          pdf-engine = "xelatex";
          variables = {
            geometry = [ "margin=1in" ];
          };
        };
      };

      programs.texlive = {
        enable = true;
        extraPackages = tpkgs: {
          inherit (tpkgs)
            latexmk biber bibtex collection-latex xetex
            fontspec unicode-math amsmath
            geometry hyperref graphics fancyhdr titlesec
            xcolor listings fancyvrb
            ;
        };
      };
    };
}
```

### 3b. `modules/research/obsidian.nix`

Nvim feature module — generates `lean/research/init.lua` + `lean/research/lsp.lua`
via `pkgs.runCommand`, merged into nvim config via `home.activation.mergeNvimFeatures`
hook. This is NOT a standalone Lua file — it's a Nix module that produces Lua
as a derivation.

**Key implementation details:**
- `legacy_commands = false` — uses new `:Obsidian <cmd>` API (decision #35)
- `picker = { name = "mini.pick" }` — forced explicitly (auto-detect failed)
- `ui.enable = false` — lean_sync colorscheme handles rendering
- Explicit `keys` for `gl`, `[o`, `]o` — custom keymaps via lazy.nvim spec
- `discover_bib_files()` — recursively globs vault dirs for `.bib` files (decision #37)
- `override.get_trigger_characters` — returns `{ "@" }` for bibtex source (decision #36)
- Two workspaces: `research` → vault, `test` → test vault

**Activation hook:** Resolves store symlink → copies dir → fixes read-only perms
→ layers feature files. Uses `lib.hm.dag.entryAfter [ "linkGeneration" ]`.

**blink-cmp bibtex merge:** Uses lazy.nvim deep-merge of the `saghen/blink.cmp`
plugin spec to add bibtex provider + per_filetype entries. No direct
modification of `completion.lua` needed.

**LSP merge:** `obsidian_ls` server returned in `lsp.servers` table, consumed
by `lsp.lua`'s pcall loop. No direct modification of `lsp.lua` needed.

### 3c. `modules/research/zotero.nix`

Flatpak desktop entry for Zotero. Wires `org.zotero.Zotero` into
application menu with MIME types.

### 3d. `modules/groups/research.nix`

Aggregates `research`, `obsidian`, `zotero` into `homeManager.researchGroup`.

### 3e. `modules/hosts/workstation.nix`

`homeManager.researchGroup` added to user imports.

---

## 4. Dependency baggage

| Component | Deps Added | Conflict | Cost |
|-----------|-----------|----------|------|
| `pandoc` (HM module) | 1 derivation | None | ~50MB store |
| `texlive` (HM module) | latexmk + biber + bibtex + collection-latex + xetex + individual pkgs | None | ~30-50MB store |
| `obsidian.nvim` | `plenary.nvim` (light) | None — completion flows through LSP | Minimal |
| `blink-cmp-bibtex` | Pure Lua, zero external deps | None — native blink.cmp source | Zero |
| `obsidian_ls` | Provided by obsidian.nvim runtime | nvim-lspconfig has built-in config | Zero |

---

## 5. Manual setup steps (not automated)

1. **Better BibTeX in Zotero**: Install from
   https://retorquere.github.io/zotero-better-bibtex/installation/
   Then configure auto-export of collections to `.bib` files in vault.
   `.bib` files are auto-discovered by recursive glob — no config edits needed.

2. **Corporate template** (optional): Generate base template with
   `pandoc -o corporate-template.docx --print-default-data-file reference.docx`,
   customize in Word, save to vault root. Reference via `--reference-doc=`.

3. **CSL style** (optional): Download a `.csl` file from
   https://www.zotero.org/styles and place in vault root.

---

## 6. Pandoc compilation keymap (deferred)

A `<space>om` keymap for markdown → .docx compilation. Deferred — not yet
implemented. See plan code at bottom of file for reference.

---

## 7. Design decisions

| Decision | Rationale |
|----------|-----------|
| User-scale only (no nixos aspect) | All research tools are user binaries; no system-level consumer |
| `programs.pandoc` over bare `home.packages` | HM module provides `--defaults` injection, template management |
| obsidian.nvim with `ui.enable = false` | lean_sync colorscheme handles rendering; conceal marks would conflict |
| obsidian.nvim with `picker = "mini.pick"` | Auto-detect failed; forces mini.pick to avoid built-in native UI |
| `legacy_commands = false` | Uses new `:Obsidian <cmd>` API; silences deprecation warnings |
| Explicit `keys` for custom keymaps | Ensures `gl`/`[o`/`]o` work regardless of obsidian.nvim's autocmd setup |
| blink-cmp-bibtex trigger override | Pandoc matcher declares no trigger chars; override forces activation on `@` |
| BibTeX auto-discovery via glob | User has many `.bib` files; manual listing is unsustainable |
| `attachments.folder` (not `img_folder`) | v4 renamed the option; `img_folder` is deprecated |
| No `follow_url_func` | Default `vim.ui.open` works; no need to override |
| blink-cmp-bibtex over cmp-zotero | Native blink.cmp source; parses .bib directly |
| texlive slim (1 collection + individual pkgs) | pandoc xelatex template deps only; ~30-50MB vs ~400-600MB full |

---

## 8. Pandoc compilation keymap (future)

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
