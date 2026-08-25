# Host Derivations

The Purpose of this directory is for users to create offshoots of the "standard" hosts found in [../] while keeping them off of the git tracked main repository. 

## Nix Evaluation

For Git to track and evaluate the new host derivation, it needs to be tracked. Use git's intent to add (--intent-to-add or -N) flag ...

```bash
git add -N <path_to_derivation_host>
```
