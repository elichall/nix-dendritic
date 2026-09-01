> **SUPERSEDED (2026-08-30) — ARCHIVED.** This plan routed Claude Pro/Max
> through opencode via the `opencode-claude-auth` plugin. PIVOT: Anthropic
> legally prohibits third-party routing of Pro/Max subscription tokens (why
> native Pro/Max OAuth was removed from opencode), and opencode 1.15.10 offers
> **API-key only** for Anthropic. Claude-specific work now goes to the
> `claude-code` CLI brought in via Nix (unfree, scoped predicate in the central
> `flake.pkgs` in flake.nix); opencode stays on the free `opencode` provider.
> Current implementation: `modules/programs/opencode.nix` + `flake.nix` +
> `modules/hosts/workstation.nix` (workstation only). See TODO.md.

# Declarative OpenCode + Claude Pro Setup with Nix (Hybrid Method)

To get a reproducible OpenCode environment that routes requests through your **Claude Pro/Max subscription**, you can combine a bleeding-edge community flake with packages managed by Nix. This allows you to avoid runtime tracking bugs or unexpected NPM network calls.

---

## 1. Prerequisites & Flake Inputs

OpenCode receives server-side changes and updates rapidly. To ensure your binary does not break due to Anthropic API adjustments, use the hourly tracking `opencode-nix` flake alongside standard `nixpkgs` (unstable).

Add the following to your system or Home Manager `flake.nix` inputs:

```nix
inputs = {
  nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  opencode-flake.url = "github:dan-online/opencode-nix";
};
```

---

## 2. Declarative Home Manager Configuration

By pulling the `opencode-claude-auth` plugin directly from `nixpkgs`, you can point OpenCode to a secure, local Nix store path instead of letting the application pull dynamic, unchecked plugin versions via `bun`/`npm` at runtime.

Add this block to your **Home Manager** user module:

```nix
{ pkgs, inputs, ... }:

{
  # 1. Install OpenCode from the tracking flake, and tools from nixpkgs
  home.packages = [
    # Bleeding-edge binary automatically synchronized with upstream changes
    inputs.opencode-flake.packages.\${pkgs.system}.default
    
    # Dependencies and authentication bridging from standard nixpkgs
    pkgs.claude-code
    pkgs.opencode-claude-auth
  ];

  # 2. Declaratively configure OpenCode to point to the local Nix-managed plugin
  home.file.".config/opencode/opencode.json".text = builtins.toJSON {
    "\$schema" = "https://opencode.ai";

    # Reference the nix-store path of the plugin directly
    "plugin" = [
      "\${pkgs.opencode-claude-auth}"
    ];

    "settings" = {
      "theme" = "tokyonight";
      "autoupdate" = false; # Let Nix remain fully in charge of upgrades
    };
  };
}
```

> ⚠️ **Community Note on `opencode-claude-auth`**: Members of the open-source community have raised security and transparency questions regarding the maintainer of this package. While multiple internal audits have found no active malware or wallet drainers, handling the plugin explicitly through your localized Nix store provides a significantly tighter sandbox and audit trail than pulling it down dynamically from live NPM registries.

---

## 3. The Imperative Handshake

While the runtime profiles, configuration assets, and packages are fully declarative, your actual active login session cannot live in the Nix store due to expiration and security limits. 

After building and switching your configuration (`home-manager switch`), complete this one-time initial handshake:

1. Log into your official Claude subscription profile inside your local environment:
   ```bash
   claude login
   ```
2. Launch your updated editor profile:
   ```bash
   opencode
   ```

The `opencode-claude-auth` plugin will discover your local `.claude/` session state automatically, recognize the active token, and begin passing prompts directly through your subscription plan.

