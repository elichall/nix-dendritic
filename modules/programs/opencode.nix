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
# - tui.json is Nix-owned (force = true); a pre-Nix `"enabled": "true"`
#   string made the whole file silently skipped by the exact-schema TUI.
{ inputs, ... }: {
  flake.modules.homeManager.opencode = { pkgs, ... }: {
    home.packages = [
      pkgs.opencode
      pkgs.poppler-utils
    ];

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

    xdg.configFile."opencode/tui.json" = {
      force = true;
      text = ''
        {
          "$schema": "https://opencode.ai/tui.json",
          "theme": "system",
          "scroll_acceleration": { "enabled": true }
        }
      '';
    };
  };
}
