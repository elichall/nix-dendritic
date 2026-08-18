# ==========================================================================
# ZOTERO
# ==========================================================================
# Only the .desktop entry is managed here; the flatpak app is installed
# via flathub (org.zotero.Zotero) and this entry wires it into the desktop.
{ inputs, ... }: {
  flake.modules.homeManager.zotero = { ... }: {
    xdg.dataFile."applications/org.zotero.Zotero.desktop".text = ''
      [Desktop Entry]
      Name=Zotero
      Exec=flatpak run --branch=stable --arch=x86_64 --command=zotero --file-forwarding org.zotero.Zotero -profile /home/elichall/.var/app/org.zotero.Zotero/profile -url @@u %U @@
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
