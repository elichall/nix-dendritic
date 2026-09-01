# ==========================================================================
# OPENCODE
# ==========================================================================
# User-scale (Home Manager): AI CLI on the user profile. No system-level
# consumer, so no nixos.* aspect.
# - poppler-utils provides pdftotext/pdftoppm/pdfinfo for the global /pdf
#   command (opencode cannot ingest PDFs natively — images only).
# - xdg.configFile."opencode/commands/pdf.md": Nix-managed GLOBAL command
#   (available in every directory/session — opencode scans the global config
#   dir for {command,commands}/**/*.md; project .opencode dirs are per-tree).
# - claude-code: Claude's own CLI for Claude-specific work (opencode stays on
#   the free `opencode` provider). claude-code is unfree — allowed via the
#   scoped predicate in flake.nix's central `flake.pkgs`, so it is added only
#   on NixOS hosts (config.host.isNixos) whose pkgs instance carries that
#   predicate. Non-NixOS hosts get claude-code from their native package
#   manager instead. Auth is a one-time `claude login` (writes
#   ~/.claude/.credentials.json).
{ inputs, ... }: {
  flake.modules.homeManager.opencode =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      home.packages =
        with pkgs;
        [
          opencode
          poppler-utils
        ]
        ++ lib.optionals (pkgs.stdenv.hostPlatform.system == "x84_64-linux") [ claude-code ];

      xdg.configFile."opencode/commands/pdf.md" = {
        force = true;
        text = ''
          ---
          description: Read and analyze a PDF by extracting its text
          ---
          Extract and read the PDF(s): $ARGUMENTS

          opencode cannot ingest PDFs natively (images only). poppler-utils is on PATH
          via Home Manager. For each PDF path:
          1. Extract text to a temp file and read it:
             `tmp="$(mktemp --suffix=.txt)" && pdftotext -layout "$FILE" "$tmp"`
             then read `$tmp` with the read tool.
          2. If the extracted text is empty or near-empty, the PDF is scanned (no text
             layer): rasterize pages with `pdftoppm -jpeg -r 150 "$FILE" /tmp/pdf-page`
             and review the page images directly.
          3. Use `pdfinfo "$FILE"` for metadata (title, pages, size) when relevant.
          4. Clean up temp files when done; quote any path containing spaces.

          Answer from the extracted content — never the filename alone.
        '';
      };
    };
}
