# ==========================================================================
# NEOVIM
# ==========================================================================
# System package exposure plus user-level editor session variables and the
# global LSP servers used by the editor (always on PATH).
#
# The dotfiles tree (_assets/dotfiles/nvim) is the last traditional config;
# it is installed read-only via xdg.configFile."nvim". Its declarative spell
# wordlist (spell/en.utf-8.add) lists BASE forms; a derivation expands them
# with plural/possessive inflections (the straight wordlist format cannot
# express affix rules) into spell/en.utf-8.expanded, compiles THAT into
# en.utf-8.add.spl (auto-loaded from <rtp>/spell/), and exposes the plain
# expanded text to ltex-ls and the harvest tool. nvim is a BUILD-ONLY
# dependency there (deliberately NOT added to PATH) — see
# _assets/plans/dictionary-expansion.md.
{ inputs, ... }: {
  flake.modules.nixos.nvim = { pkgs, ... }: {
    environment.systemPackages = [ pkgs.neovim ];
  };

  flake.modules.homeManager.nvim =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      spellDir = ../_assets/dotfiles/nvim/spell;
      baseWordlist = builtins.readFile (spellDir + "/en.utf-8.add");

      # ----------------------------------------------------------------------
      # Build-time inflection expansion. The straight .add wordlist format only
      # supports =/?/! and region flags — affixes (SFX/PFX) need a Myspell
      # .aff/.dic pair, so plural + possessive forms are derived here instead.
      # The expanded set is what gets compiled into the .spl and read by ltex.
      # ----------------------------------------------------------------------

      # Base words that are already plural / irregular: never derive a plural.
      pluralSkip = [
        "moduli"
        "minima"
      ];

      # Bare base words from the wordlist (comments/blank/flag lines dropped).
      baseWords =
        let
          lines = lib.splitString "\n" baseWordlist;
          words = lib.filter (w: w != null) (
            map (
              line:
              let
                m = builtins.match "^([-a-zA-Z0-9']+).*" line;
              in
              if m == null then null else builtins.head m
            ) lines
          );
        in
        lib.filter (w: !lib.hasPrefix "_" w) words;

      # Regular pluralization, tuned for this wordlist.
      pluralOf =
        w:
        if lib.elem w pluralSkip then
          null
        else if lib.hasSuffix "s" w then
          null # already plural / plural-only
        else if lib.hasSuffix "ly" w then
          null # adverbs never pluralize
        else if builtins.match ".*[0-9]" w != null then
          null # AA7050 → no AA70500
        else if lib.hasSuffix "y" w then # consonant+y -> -ies
          lib.substring 0 (builtins.stringLength w - 1) w + "ies"
        else if lib.hasSuffix "x" w || lib.hasSuffix "z" w then
          w + "es"
        else
          w + "s";

      expand =
        w:
        let
          p = pluralOf w;
        in
        [
          w
          (w + "'s")
        ]
        ++ lib.optional (p != null) p;

      expandedWords = lib.unique (lib.sort (a: b: a < b) (lib.concatMap expand baseWords));
      expandedWordlist = lib.concatStringsSep "\n" expandedWords + "\n";

      expandedSpell = pkgs.writeText "en.utf-8.expanded" expandedWordlist;

      # Compile the declarative spell wordlist into <rtp>/spell/ so vim loads
      # it automatically (:h spell-load). nvim is a build dependency only.
      nvimDotfiles = pkgs.stdenv.mkDerivation {
        name = "nvim-dotfiles";
        src = ../_assets/dotfiles/nvim;
        nativeBuildInputs = [ pkgs.neovim ];
        buildPhase = ''
          mkdir -p "$out"
          cp -r "$src/." "$out"
          chmod -R u+w "$out"
          # Base + derived inflections, consumed by lsp.lua and the harvest tool.
          cp ${expandedSpell} "$out/spell/en.utf-8.expanded"
          # Compile the EXPANDED set (not the bare base) into <rtp>/spell/.
          # mkspell names the output after the input file, so build in a temp
          # dir from a copy named en.utf-8.add.
          mkdir -p "$out/spell/.splbuild"
          cp "$out/spell/en.utf-8.expanded" "$out/spell/.splbuild/en.utf-8.add"
          (cd "$out/spell/.splbuild" && HOME="$TMPDIR" nvim -u NONE -i NONE -es +"mkspell! en.utf-8.add" +qa)
          mv "$out/spell/.splbuild/en.utf-8.add.spl" "$out/spell/en.utf-8.add.spl"
          rm -rf "$out/spell/.splbuild"
        '';
        installPhase = "true";
      };
    in
    {
      home.sessionVariables = {
        EDITOR = "nvim";
        VISUAL = "nvim";
        SUDO_EDITOR = "nvim";
      };

      home.packages = with pkgs; [
        neovim # for non-os level builds
        nil # nix
        marksman # markdown
        lua-language-server # lua
        texlab # latex
        bash-language-server # bash
        tree-sitter # tree-sitter grammar CLI
        ltex-ls # markdown/tex grammar + scientific dictionary (spell.lua)
      ];

      xdg.configFile."nvim" = {
        source = nvimDotfiles;
        recursive = true;
        force = true;
      };
    };
}
