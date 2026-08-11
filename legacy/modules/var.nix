# Central shared vars. Flip an appId here -> rebuild -> all consumers follow.
# Add future concerns (terminal, editor, file manager, ...) with the same pattern.
{
  browser = let
    appId = "app.zen_browser.zen";
  in {
    appId   = appId;
    command = "flatpak run ${appId}";
    desktop = "${appId}.desktop";
  };
}
