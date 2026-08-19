# ==========================================================================
# RESEARCH WORKFLOW
# ==========================================================================
# User-scale research toolchain: Pandoc (markdown→docx/pdf compilation with
# built-in citeproc), TeX Live (xelatex + latexmk + biber/bibtex for vimtex
# and pandoc PDF output). All user-scale — no nixos aspect.
#
# Slim texlive: only packages required by pandoc's default xelatex template.
# If a document needs additional LaTeX packages, add them to extraPackages.
#
# Build artifacts are redirected to .build/ via .latexmkrc in the vault root.
# Add .build/ to your .gitignore.
# ==========================================================================
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
            latexmk # build tool (vimtex + pandoc)
            biber # biblatex processor
            bibtex # traditional bibtex processor
            collection-latex # core LaTeX format + infrastructure
            # pandoc default xelatex template dependencies:
            xetex
            fontspec # xelatex font selection
            unicode-math # xelatex math font support
            amsmath # math typesetting
            geometry
            hyperref
            graphics
            fancyhdr
            titlesec
            xcolor
            listings
            fancyvrb
            booktabs # pandoc default template (table rules)
            mdwtools # pandoc default template (footnote.sty for table footnotes)
            ;
        };
      };

      # Redirect LaTeX build artifacts (.aux, .bbl, .blg, etc.) to .build/
      home.file."Documents/me/vault/.latexmkrc".text = ''
        $out_dir = ".build";
        $pdf_mode = 5;  # xelatex
        $bibtex_use = 2;
      '';
    };
}
