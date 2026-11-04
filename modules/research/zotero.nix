# ==========================================================================
# ZOTERO
# ==========================================================================
# The flatpak app itself is installed by hand from flathub (org.zotero.Zotero).
# Managed here: the .desktop entry that wires it into the desktop, and the
# user-level flatpak permission override (same file Flatseal would write to
# ~/.local/share/flatpak/overrides/, so it follows the user to every host).
# Because HM owns that file it is a read-only symlink: change permissions here,
# not in Flatseal.
# NOTE: the entry deliberately has NO `-profile <dir>` argument. A hardcoded
# profile path that doesn't exist on a host opens a "Profile Missing" dialog
# (otter menu "does nothing") while plain `flatpak run` uses the default
# profile fine. Add `-profile` back only together with creating that directory.
{ inputs, ... }: {
  flake.modules.homeManager.zotero = { ... }: {
    # Drop the default whole-home access and grant the session bus.
    # NB: the key is `filesystems` (plural), as Flatseal writes it.
    xdg.dataFile."flatpak/overrides/org.zotero.Zotero".text = ''
      [Context]
      sockets=session-bus;
      filesystems=!home;
    '';


    xdg.dataFile."applications/org.zotero.Zotero.desktop".text = ''
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
}
