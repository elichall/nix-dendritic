# Research Workflow Stack

Terminal-centric research pipeline: Neovim as primary editor for an
Obsidian vault, Zotero/Better BibTeX for bibliography, Pandoc for
markdown-to-.docx compilation with built-in citeproc. Vault lives at
`~/Documents/me/vault/research`.

**Status**: PLAN — not yet implemented.

---

## 1. Architecture

| Layer | Tool | Role |
|-------|------|------|
| **Storage** | Obsidian vault (`~/Documents/me/vault/research/`) | Flat markdown files; Obsidian app as secondary visual canvas |
| **Editor** | Neovim + obsidian.nvim | Primary editing interface; in-process LSP for wiki-link completion, backlinks, rename |
| **Bibliography** | Zotero + Better BibTeX → `references.bib` | Citation key database; live-updating `.bib` file |
| **Citation completion** | blink-cmp-bibtex | Native blink.cmp source; parses `.bib`, shows APA/IEEE previews |
| **Compilation** | Pandoc (built-in citeproc) | Markdown → .docx with bibliography resolution and corporate template overlay |
| **LaTeX** | vimtex + texlive (latexmk/biber/bibtex) | LaTeX compilation for .tex files; pandoc PDF fallback |
| **Workspace** | Tmux + Ghostty | Splits editing buffer from compilation outputs |

### Data flow

```
Zotero ──Better BibTeX──▶ references.bib ──blink-cmp-bibtex──▶ @citekey autocomplete
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

### What's missing

- No pandoc, latexmk, bibtex, or biber on PATH
- No obsidian.nvim plugin
- No citation completion source for blink.cmp
- No Pandoc compilation keymap
- No `.bib` files in vault (Better BibTeX not yet configured in Zotero)

---

## 3. Implementation plan

### 3a. New file: `modules/programs/research.nix`

`homeManager.research` module — user-scale pandoc + texlive.

```nix
# ==========================================================================
# RESEARCH WORKFLOW
# ==========================================================================
# User-scale research toolchain: Pandoc (markdown→docx compilation with
# citeproc), TeX Live (latexmk + biber + bibtex for vimtex and pandoc
# PDF output).
#
# Requires: Better BibTeX plugin installed in Zotero (manual step —
# configure auto-export to ~/Documents/me/vault/research/references.bib).
# ==========================================================================
{ inputs, ... }: {
  flake.modules.homeManager.research = { pkgs, ... }: {
    programs.pandoc = {
      enable = true;
      defaults = {
        citeproc = true;
        pdf-engine = "xelatex";
      };
    };

    programs.texlive = {
      enable = true;
      extraPackages = tpkgs: {
        inherit (tpkgs)
          latexmk
          biber
          bibtex
          collection-fontsrecommended
          collection-latexextra;
      };
    };

    home.packages = with pkgs; [
      ripgrep # obsidian.nvim hard-dependency
    ];
  };
}
```

**Design rationale:**
- `programs.pandoc` (Home Manager module) wraps pandoc with `--defaults` injection;
  `citeproc = true` enables built-in citation processing (pandoc ≥ 2.11 has
  citeproc integrated — no external `pandoc-citeproc` filter needed).
- `programs.texlive` with `latexmk` (vimtex build tool, `lsp.lua:107`), `biber` +
  `bibtex` (bibliography processors), `collection-fontsrecommended` +
  `collection-latexextra` (common LaTeX packages for document compilation).
- `ripgrep` declared here as obsidian.nvim hard-depends on it for search features.
  List merge deduplicates harmlessly if declared elsewhere.
- All user-scale per architecture directive — no `nixos.research` aspect.

**Store cost:** texlive collections are ~200-400MB. pandoc is ~50MB. Acceptable
for a research workflow; can slim texlive later if only `latexmk` is needed.

### 3b. New file: `modules/_assets/dotfiles/nvim/lua/lean/plugins/research.lua`

lazy.nvim plugin spec for obsidian.nvim + blink-cmp-bibtex.

```lua
return {
  -- ========================================================================
  -- OBSIDIAN VAULT INTEGRATION
  -- ========================================================================
  -- Neovim as primary editor for the Obsidian vault. Provides an in-process
  -- LSP server (obsidian_ls) that understands [[wiki-links]], backlinks,
  -- note renaming with vault-wide link updates, tags, and daily notes.
  --
  -- Picker falls back to built-in native UI for obsidian-specific pickers
  -- (:ObsidianBacklinks, :ObsidianTags, :ObsidianToc). General file finding
  -- stays with mini.pick.
  --
  -- Completion flows through blink.cmp's LSP source → obsidian_ls — no
  -- nvim-cmp dependency.
  -- ========================================================================
  {
    "obsidian-nvim/obsidian.nvim",
    version = "*",
    ft = "markdown",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {
      workspaces = {
        {
          name = "research",
          path = "~/Documents/me/vault/research",
        },
      },

      completion = {
        min_chars = 2,
        match_case = false,
        create_new = false, -- don't prompt to create notes on failed completion
      },

      -- Built-in native picker (no telescope/fzf-lua dep).
      -- Auto-detects mini.pick for general use; obsidian-specific pickers
      -- (:ObsidianBacklinks, :ObsidianTags, :ObsidianToc) use the fallback.
      picker = {
        name = nil,
      },

      -- Disable obsidian UI decorations — lean_sync colorscheme + md-view.nvim
      -- handle rendering. Obsidian's conceal marks would conflict.
      ui = {
        enable = false,
      },

      follow_url_func = function(url)
        vim.fn.jobstart({ "xdg-open", url })
      end,

      daily_notes = {
        folder = "daily",
        date_format = "%Y-%m-%d",
        alias_format = "%B %-d, %Y",
        default_tags = { "daily" },
        template = nil,
      },

      attachments = {
        img_folder = "attachments",
        img_name_func = function()
          return string.format("%s-%s",
            os.date("%Y-%m-%d-%H%M%S"),
            vim.fn.input("Image name: "))
        end,
      },
    },
  },

  -- ========================================================================
  -- BIBTEX CITATION COMPLETION (blink.cmp source)
  -- ========================================================================
  -- Native blink.cmp source that parses .bib files and provides @citekey
  -- completion with APA/IEEE title+author+year previews.
  --
  -- Auto-discovers .bib from:
  --   1. global_files config (references.bib in vault root)
  --   2. \addbibresource{} in LaTeX files
  --   3. YAML bibliography: field in markdown frontmatter
  -- ========================================================================
  {
    "krissen/blink-cmp-bibtex",
    ft = { "markdown", "tex", "plaintex" },
    dependencies = {
      "saghen/blink.cmp",
    },
    opts = {
      global_files = {
        vim.fn.expand("~/Documents/me/vault/research/references.bib"),
      },
      preview_style = "apa",
    },
  },
}
```

**obsidian.nvim unique features (not replicable by oil + mini.pick):**

| Feature | Why it matters |
|---------|---------------|
| Backlinks (`:ObsidianBacklinks`) | Finds all notes referencing the current note by ID/alias — vault-wide semantic grep understanding `[[wiki-links]]` |
| Rename with link update (`:ObsidianRename`) | Renames a note AND updates every backlink across the entire vault |
| In-process LSP (`obsidian_ls`) | Wiki-link completion (`[[`), tag completion (`#`), footnote completion (`[^`) — semantic markdown knowledge |
| `[[wiki-link]]` navigation | `<CR>` follows links, creates target note on-the-fly if it doesn't exist |
| Daily notes | Date-aware note creation with configurable format/aliases/templates |
| Image paste | `:Obsidian paste_img` saves clipboard image to vault attachments folder |

**Picker strategy:** `picker.name = nil` → auto-detects mini.pick → falls back
to built-in native picker for obsidian-specific pickers. This avoids adding
telescope or fzf-lua as dependencies.

### 3c. Modify: `completion.lua`

Add `bibtex` provider and wire it into markdown/tex filetypes:

```lua
-- Add to sources.providers:
providers = {
  -- ... existing spell provider ...
  bibtex = {
    name = "BibTeX",
    module = "blink-cmp-bibtex",
    opts = {},
    async = true,
    min_keyword_length = 2,
  },
},

-- Update per_filetype to include bibtex:
per_filetype = {
  markdown = { "lsp", "path", "snippets", "buffer", "spell", "bibtex" },
  text = { "path", "snippets", "buffer", "spell" },
  tex = { "lsp", "path", "snippets", "buffer", "spell", "bibtex" },
  plaintex = { "lsp", "path", "snippets", "buffer", "spell", "bibtex" },
},
```

### 3d. Modify: `lsp.lua`

Add `obsidian_ls` to the LSP server registry so blink.cmp can consume its
completion items (wiki-links, tags, footnotes):

```lua
-- Add to target_servers list (after "ltex"):
"obsidian_ls",
```

`obsidian_ls` is provided by obsidian.nvim's runtime — no extra nix package
needed. nvim-lspconfig has a built-in server config for it.

### 3e. Modify: `otter-launcher/config.toml`

Uncomment and complete the `obs` module — opens the vault root in nvim
(Oil.nvim takes over as file explorer):

```toml
[[modules]]
description = "vault"
prefix = "obs"
cmd = """
setsid -f ghostty --class=com.waybar.tui -e bash -c 'cd ~/Documents/me/vault/research && exec nvim .'
"""
```

### 3f. Modify: `groups/desktop.nix`

Add `research` to `homeManager.desktop` imports.

### 3g. Modify: `hosts/workstation.nix`

Add `homeManager.research` to user imports.

### 3h. Modify: `module-contracts.md`

Add registry row:

```
| `homeManager.research` | `programs/research.nix` | pandoc (HM module, citeproc defaults) + texlive (latexmk/biber/bibtex/collections) + ripgrep |
```

Add contract:

```
### C20. Research vault path
- Vault: `~/Documents/me/vault/research`
- `blink-cmp-bibtex` auto-discovers `references.bib` from this path.
- `obsidian.nvim` workspace points here.
- Better BibTeX auto-export: manual Zotero setup (install plugin, configure
  auto-export to `references.bib` in Better BibTeX format).
```

### 3i. Modify: `TODO.md`

Add entries for the research workflow module.

---

## 4. Dependency baggage

| Component | Deps Added | Conflict | Cost |
|-----------|-----------|----------|------|
| `pandoc` (HM module) | 1 derivation | None | ~50MB store |
| `texlive` (HM module) | latexmk + biber + bibtex + 2 collections | None | ~200-400MB store |
| `obsidian.nvim` | `plenary.nvim` (light, often already present) | None — completion flows through LSP, not nvim-cmp | Minimal |
| `blink-cmp-bibtex` | Pure Lua, zero external deps | None — native blink.cmp source | Zero |
| `ripgrep` | 1 derivation | May already be declared; list merge deduplicates | Harmless |
| `obsidian_ls` | Provided by obsidian.nvim runtime | nvim-lspconfig has built-in config | Zero |

**Heaviest dep:** texlive with collections. Can slim to just `latexmk + bibtex + biber`
if full LaTeX compilation isn't needed (vimtex only needs latexmk).

---

## 5. Manual setup steps (not automated)

1. **Better BibTeX in Zotero**: Install from
   https://retorquere.github.io/zotero-better-bibtex/installation/
   Then configure auto-export of a collection to
   `~/Documents/me/vault/research/references.bib` (Better BibTeX format).

2. **Corporate template** (optional): Generate base template with
   `pandoc -o corporate-template.docx --print-default-data-file reference.docx`,
   customize fonts/headers in Microsoft Word, save to vault root.
   Reference in pandoc keymap via `--reference-doc=`.

3. **CSL style** (optional): Download a `.csl` file (APA, IEEE, Harvard, etc.)
   from https://www.zotero.org/styles and place in vault root.
   Reference via `--csl=style.csl` in pandoc command.

---

## 6. Pandoc compilation keymap (future addition to `research.lua`)

A `<space>om` keymap for markdown → .docx compilation. Deferred to
implementation — here for reference:

```lua
vim.keymap.set("n", "<leader>om", function()
  local file = vim.api.nvim_buf_get_name(0)
  local output = file:gsub("%.md$", ".docx")
  local bib_file = vim.fn.expand("~/Documents/me/vault/research/references.bib")
  local reference_doc = vim.fn.expand("~/Documents/me/vault/research/corporate-template.docx")

  local cmd = { "pandoc", file, "-o", output }

  -- Only add bibliography if the .bib file exists
  if vim.fn.filereadable(bib_file) == 1 then
    table.insert(cmd, "--bibliography=" .. bib_file)
  end
  -- Only add reference-doc if the template exists
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

---

## 7. Design decisions

| Decision | Rationale |
|----------|-----------|
| User-scale only (no nixos aspect) | All research tools are user binaries; no system-level consumer |
| `programs.pandoc` over bare `home.packages` | HM module provides `--defaults` injection, template management, and CSL installation |
| obsidian.nvim with `ui.enable = false` | lean_sync colorscheme handles rendering; obsidian's conceal marks would conflict |
| obsidian.nvim with `picker.name = nil` | Avoids telescope/fzf-lua dependency; built-in picker handles obsidian-specific commands |
| blink-cmp-bibtex over cmp-zotero | Native blink.cmp source; no compat layer needed; parses .bib directly (no Zotero sqlite coupling) |
| `references.bib` in vault root | Single source of truth; blink-cmp-bibtex auto-discovers from global_files + markdown YAML frontmatter |
| texlive with full collections | Research workflow needs diverse LaTeX packages; can slim later if store cost is a concern |
