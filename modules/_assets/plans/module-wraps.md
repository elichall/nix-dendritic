# Wrapper Modules

I saw the concept of module wraps in a vimjoyer video (https://www.youtube.com/watch?v=aNgujRXDTdE).

They alloy for you to nix run the module specifically and test changes in an isolated environment without having to rebuild a system. They also look like a good method of ensuring module isolation.

EX:
```nix
{ self, inputs, ...": {
    flake.nixosModule.niri = { pkgs, lib, ... }: {
        programs.niri = {
            enable = true;
            package = self.package.${pkgs.stdenv.hostPlatform.system}.myNiri;
        };
    };

    perSystem = { pkgs, lib, ... }: {
        packages.myNiri = inputs.wrapper-modules.wrappers.niri.wrap {
            settings = {
                input.keyboard = {
                    xkb.layout = "us,ua";
                };

                layout.gaps = 5;

                binds = {
                    <...>
```
