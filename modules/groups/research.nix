# ==========================================================================
# RESEARCH GROUP — research toolchain preset
# ==========================================================================
# Aggregates research-aspect modules: toolchain (pandoc/texlive), Obsidian
# vault nvim integration, and Zotero bibliography. Individual keys remain
# importable. Wired via `self.modules.homeManager.research`.
{ self, ... }: {
  flake.modules.homeManager.researchGroup = {
    imports = [
      self.modules.homeManager.research
      self.modules.homeManager.obsidian
      self.modules.homeManager.zotero
    ];
  };
}
