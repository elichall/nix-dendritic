# ==========================================================================
# ZOTERO (flatpak org.zotero.Zotero — installed by hand from flathub)
# ==========================================================================
# Registry entry (modules/options/flatpakOpt.nix); the renderer in flatpak.nix
# writes the override + .desktop entry. HM owns those files read-only: change
# permissions here, not in Flatseal.
# NOTE: the entry deliberately has NO `-profile <dir>` argument. A hardcoded
# profile path that doesn't exist on a host opens a "Profile Missing" dialog
# (otter menu "does nothing") while plain `flatpak run` uses the default
# profile fine. Add `-profile` back only together with creating that directory.
{ ... }: {
  flake.modules.homeManager.flatpakZotero = { ... }: {
    flatpak.apps."org.zotero.Zotero" = {
      # Drop the default whole-home access and grant the session bus.
      # NB: the key is `filesystems` (plural), as Flatseal writes it.
      overrides = ''
        [Context]
        sockets=session-bus;
        filesystems=!home;
      '';

      desktopEntry = ''
        [Desktop Entry]
        Name=Zotero
        Exec=flatpak run --branch=stable --arch=x86_64 --command=zotero --file-forwarding org.zotero.Zotero -url @@u %U @@
        Icon=org.zotero.Zotero
        Type=Application
        Terminal=false
        Categories=Office;Science
        MimeType=text/plain;x-scheme-handler/zotero;application/x-research-info-systems;text/x-research-info-systems;text/ris;application/x-endnote-refer;application/x-inst-for-Scientific-info;application/mods+xml;application/rdf+xml;application/x-bibtex;text/x-bibtex;application/marc;application/vnd.citationstyles.style+xml
        X-GNOME-SingleWindow=true
        Keywords=bibliography;biblatex;bibtex;citing;literature
      '';
    };
  };
}
