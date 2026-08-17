# Session Resume — Spell Inflection + Case Enforcement (2026-08-16)

Continuation notes for the dictionary-expansion work stream. Pair with
`dictionary-expansion.md` (original plan). Read this FIRST when resuming.

---

## 1. WHERE WE ARE (exact state)

### Done + staged (NOT committed)
- `modules/programs/nvim.nix`: `expandWordlist` implemented — pure-Nix inflection
  generation. Base wordlist → `en.utf-8.expanded` (base + `'s` possessive + plural)
  via `pkgs.writeText`; derivation copies it in, then mkspells the EXPANDED set
  into `en.utf-8.add.spl` from a temp dir (`$out/spell/.splbuild/`, temp file named
  `en.utf-8.add` so the `.spl` gets the right load name). Outputs:
  `en.utf-8.add` (base, readable) / `en.utf-8.expanded` / `en.utf-8.add.spl`.
- `lsp.lua`: `load_scientific_dictionary()` now prefers `en.utf-8.expanded`,
  falls back to `en.utf-8.add`.
- `spell/en.utf-8.add`: normalized to BASE forms (removed generated plurals:
  recrystallizations, microstructures, dendrites, polycrystals, subgrains, pdes,
  odes, timesteps, jacobians, verlets, thermocouples, eigenvalues, eigenvectors,
  wavefunctions, datasets, pinns, copinns, pdes-in-acronyms-section; deduped
  `incompressible` + `spdp`). Now 216 base words. Header documents base-form rule.
- `tools/harvest-spellbad`: rewritten — `--wordlist PATH` override, script-relative
  resolution (`arg[0]` → `../spell/`), `stdpath("config")` fallback; prefers
  `en.utf-8.expanded`, else mirrors Nix plural rules inline. STRICTLY stdout-only
  (guaranteed additive, per user requirement).
- Built derivation: `/nix/store/7pbgb8s1d0q7008dpqjc47yniig0vnbm-nvim-dotfiles`
  (616-line expanded file, verified correct inflections — no `modulis`/`minimas`/
  `additivelies`/`dimensionlesslies`, `weldabilities`/`anisotropies`/`enthalpies`
  present, `flow-stress` possessive but not plural, `verlets` generated).

### Open problem (the reason work stopped)
The vault writes acronyms/names in CAPS/Title-Case, and vim's case rules reject
the derived mixed-case forms:
- `AFSD's`, `AFSDs`, `PDEs`, `PINNs` → BAD with a lowercase-only wordlist.
- Even the MAIN dict rejects `DVDs`/`GPUs`/`CDs` (only as `local`/other-region).
- Discovered PRE-EXISTING gap: Title-Case proper names (`Zener-Hollomon`,
  `Navier-Stokes`, `Bammann-Chiesa-Johnson`, `Kocks-Mecking-Estrin`,
  `Courant-Friedrichs-Lewy`, `Johnson-Mehl-Avrami-Kolmogorov`) FAIL spellcheck
  today because wordlist entries are lowercase. `Johnson-Cook` only passes by
  coincidence (main-dict compound: Johnson+Cook both known).

### User decisions this session
1. Harvest tool: **stdout-only** (never writable → additive by construction). DONE.
2. Wordlist normalization to base forms: approved. DONE.
3. **"i wouldn't mind acronyms needing to be capitalized to pass the spell check,
   it would make things more professional"** → store acronyms in CAPS, proper
   names in Title-Case. DESIGN VALIDATED but NOT APPLIED.

---

## 2. THE CASE RULE (critical, verified empirically)

From `:h spell-wordlist-format`:

```
word list   matches          does not match
als         als Als ALS      ALs AlS aLs aLS
```

- A lowercase dict word matches: lowercase, first-letter-cap, all-caps.
  Does NOT match mixed-case like `ALs`.
- A dict word WITH uppercase letters requires those letters uppercase
  (all-caps input is still OK).
- ⇒ To accept `AFSD's`/`PDEs`, the dict must contain those EXACT mixed-case
  forms. Storing the base acronym in CAPS makes generation produce them.

### Validation test (isolated — see §4 for the isolation gotcha)
Test wordlist with `afsd, AFSDs, AFSD's, pde, PDEs, pinn, PINNs, gpu, gpus,
GPUs, isv, isvs, ISVs, moe-pinn, tr-afsd, AFS-D` compiled to spl:

```
afsd -> GOOD     AFSD -> GOOD     AFSDs -> GOOD     AFSD's -> GOOD
AFSD'S -> GOOD   AFSDS -> GOOD    afsds -> BAD(bad)
pde -> GOOD      PDE -> GOOD      PDEs -> GOOD      PDE's -> BAD (not in list)
PINNs -> GOOD    pinns -> BAD     PINN's -> BAD     (not in list)
gpu/GPU/GPUs/gpus -> GOOD         isv/ISV/ISVs/isvs -> GOOD
afs-d -> BAD     AFS-D -> GOOD    AFS-D's -> BAD    (no possessive entry)
afsdss/PDEss/AFSDss -> BAD(bad)   ← NO over-acceptance
```

CONCLUSION: acronym-CAPS works exactly as intended. Lowercase acronyms correctly
rejected (user wants this). No `AFSDss`-style over-acceptance from vim's `.spl`.

---

## 3. NEXT STEPS (in order)

1. **Uppercase acronyms in `spell/en.utf-8.add`** (vault-verified all-caps):
   `AFSD, TR-AFSD, AFS-D, SPD, SPDP, SPH, XSPH, TL-SPH, PDE, ODE, FCC, BCC, HCP,
   EBSD, SHPB, CDRX, DDRX, GDRX, CSPM, GPGPU, CUDA, SYCL, AA7050, AA7075, PINN`.
   Convert plural-only → singular bases so generation makes the caps plurals:
   `isvs→ISV, gpus→GPU, tpus→TPU, npus→NPU, lnns→LNN` (vault: ISVs/GPUs caps).
   Leave lowercase (no vault cap evidence / ambiguous): `moe-pinn, copinn,
   ti64` (lowercase `ti64` still matches `Ti64`), `bcc`/`hcp` (0 vault uses —
   keep CAPS anyway, standard crystallography).
2. **Title-Case proper model names + surnames** (vault writes these capitalized;
   lowercase entries FAIL the caps forms):
   `Johnson-Cook, Zener-Hollomon, Sellars-Tegart, Fields-Backofen,
   Bammann-Chiesa-Johnson, Kocks-Mecking-Estrin, Taylor-Quinney,
   Zerilli-Armstrong, Ramberg-Osgood, Hall-Petch, Levy-Mises, Moore-Penrose,
   Newton-Raphson, Gauss-Seidel, Levenberg-Marquardt, Courant-Friedrichs-Lewy,
   Mie-Gruneisen, Gruneisen, Navier-Stokes, Kubin-Estrin,
   Johnson-Mehl-Avrami-Kolmogorov, Split-Hopkinson` and single surnames `Poisson,
   Cauchy, Jaumann, Orowan, Peierls, Voce, Kocks, Mecking, Estrin, Mises, Taylor,
   Euler, Verlet, Monaghan, Wendland, Galerkin, Hopkinson, Kolsky, Gleeble,
   Schrodinger, Markov, Monte, Carlo, Coriolis, Vickers`. Keep `bayesian`
   lowercase (adjectival, common lowercase; `Bayesian` first-cap still matches).
3. **nvim.nix fixes** (required for the caps/digit words):
   - `baseWords` regex must include digits: `"^([-a-zA-Z0-9']+).*"` (else `AA7050`
     parses as `AA`).
   - `pluralOf`: add digit-suffix skip (`AA7050` → would generate `AA70500`
     otherwise): `else if lib.hasSuffix "0" w || ... 0-9` — use
     `builtins.match "[0-9]$"` or `lib` predicates; simplest is a guard before
     the `y`/`x`/`z` checks: `else if lib.any (d: lib.hasSuffix d w) ["0".."9"] then null`.
4. **lsp.lua loader**: pattern `^([%a%-]+)` → `^([%a%d%-]+)` so `AA7050` loads
   fully (currently truncates at the digit).
5. **harvest-spellbad**: (a) load known-set lowercased (`known[w:lower()]=true`)
   so the tool stays vocabulary-only and doesn't report case violations; (b) add
   `%d` to the scan tokenizer `[%a%-]+`→`[%a%d%-]+` and the `add()` filter
   `^[%a%-]+$`→`^[%a%d%-]+$` so `AA7050` etc. tokenize whole.
6. **Rebuild + validate** (see §4 for isolation):
   - `nix build .#nixosConfigurations.workstation.config.home-manager.users.elichall.xdg.configFile."nvim".source`
   - isolated matrix (test dir in `/tmp/opencode/spelltest/`): GOOD: `AFSD`,
     `AFSDs`, `AFSD's`, `AFSD'S`, `PDEs`, `PINNs`, `ISVs`, `GPUs`, `AA7050`,
     `AA7050's`, `Zener-Hollomon`, `Zener-Hollomon's`, `Johnson-Cook`,
     `Johnson-Cook's`, `Sellars-Tegart`, `Levy-Mises`, `Peierls`, `Peierls's`,
     `Voce`, `Kocks`, `Navier-Stokes`, lowercase-matching common words
     (`weldabilities`, `anisotropies`, `feedstocks`, `recrystallizations`).
     BAD: `afsd` (lowercase), `afsds`, `afsdzx`, `afsdss`, `PDEss`,
     `zener-hollomon` (lowercase), `AA70500`, `Zener-Hollomons's`-type garbage.
   - `activationPackage` + toplevel eval pass.
7. **Docs**: update `dictionary-expansion.md` (case policy + inflection rules),
   `module-contracts.md` nvim row, `TODO.md`.
8. **User deploys**: `snorbs` (re-run — the earlier `force = true` fix on
   `xdg.configFile."nvim"` is staged but never deployed). Then test ltex-ls
   over-acceptance: if it accepts `AFSDss`/`PDEss`, trim ltex dict to base-only.

---

## 4. TESTING GOTCHAS (learned the hard way)

- **`~/.config/nvim` is in nvim's default runtimepath EVEN with `-u NONE`** —
  headless tests silently load the DEPLOYED config's spl and give garbage
  results. ALWAYS isolate: `XDG_CONFIG_HOME=/tmp/opencode/emptyconfig nvim -u
  NONE -l <script>` and `vim.opt.rtp:prepend("<dir-with-spell-subdir>")`.
- The dump trick: `vim.cmd("spelldump")` then read the current buffer — the
  loaded spl words (see the contaminated dump that showed deployed words
  `pdes/copinns/gpgpu/isvs` proving the wrong spl had loaded).
- `builtins.match` returns `[]` (NOT `null`) when the regex matches with NO
  capture group → wrap in a capture group: `"^([-a-zA-Z']+).*"`.
- `mkspell` names output after input file → temp-dir copy named `en.utf-8.add`.
- nvim build invocation (works, in nvim.nix): `(cd "$out/spell/.splbuild" &&
  HOME="$TMPDIR" nvim -u NONE -i NONE -es +"mkspell! en.utf-8.add" +qa)`.
- Apostrophe words ARE valid in the straight wordlist (`'s mornings` is in the
  docs) — `afsd's` compiles fine.

## 5. VAULT CASE-USAGE EVIDENCE (grep of ~/Documents/me/vault)

```
afsd 16t/147CAPS/2low   sph 15t/190/12   pinn 9t/22/7   pde 3t/0/4
ode 3t/0/1   isv 4t/9/0   gpu 9t/22/0   npu 2t/1/0   cdrx 2t/10/0
ddrx 1t/1/0   gdrx 1t/1/0   shpb 4t/13/0   ebsd 2t/8/0   fcc 2t/3/0
spd 5t/12/0   spdp 1t/3/0   cspm 2t/3/0   xsph 4t/5/0   cuda 7t/7/0
gpgpu 1t/1/0   TR-AFSD 1cap   AFS-D 3cap   TL-SPH 1cap   AA7050 54cap
AA7075 5cap   SYCL 1cap   (moE-pinn/copinn/opencl/ti64: 0 evidence)
Model names Title-Case: Zener-Hollomon x10, Johnson-Cook x20, Sellars-Tegart
x13, Fields-Backofen x4, Taylor-Quinney x4, Zerilli-Armstrong x2, + several x1.
```
`pde`/`ode` are currently written LOWERCASE in the vault but user explicitly
wants `PDEs` to pass → user intends caps; lowercase `pdes` will be flagged
after this change (acceptable per user's "more professional" statement).

## 6. FILE MAP

- `modules/programs/nvim.nix` — expansion + derivation (needs: regex digits, digit-skip).
- `modules/_assets/dotfiles/nvim/spell/en.utf-8.add` — 216 base words (needs: caps + Title-Case).
- `modules/_assets/dotfiles/nvim/lua/lean/plugins/lsp.lua` — ltex loader (needs: `%d`).
- `modules/_assets/dotfiles/nvim/tools/harvest-spellbad` — additive harvest (needs: lowercase known-set + `%d`).
- `modules/_assets/plans/dictionary-expansion.md` — original plan (needs: case-policy section).
- `modules/_assets/module-contracts.md` row 51 — nvim contract (needs refresh).
- Test artifacts live in `/tmp/opencode/spelltest/` (test wordlist, check.lua,
  clean spl) and `/tmp/opencode/spellcheck-*.lua` matrices.

## 7. BLOCKED / REMINDERS

- User must re-run `snorbs` after this lands (first attempt failed on HM
  clobber; `force = true` staged, never deployed).
- ltex-ls over-acceptance verdict pending user's post-deploy test.
- Flake source filter requires `git add` before builds pick up new file content.
- `post-switch-smoke-test.sh` deleted by user — do NOT recreate.
