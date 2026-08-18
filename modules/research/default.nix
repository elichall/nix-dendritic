# ==========================================================================
# RESEARCH WORKFLOW
# ==========================================================================
# User-scale research toolchain: Pandoc (markdown→docx/pdf compilation with
# built-in citeproc), TeX Live (xelatex + latexmk + biber/bibtex for vimtex
# and pandoc PDF output). All user-scale — no nixos aspect.
#
# Slim texlive: only packages required by pandoc's default xelatex template.
# If a document needs additional LaTeX packages, add them to extraPackages.
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
            ;
        };
      };
    };
}
