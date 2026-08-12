# OpenCode Power User Configuration

## 1. File and Media Ingestion
OpenCode supports standard image formats natively but requires explicit workarounds for binary PDFs.

### Image Processing
* **Formats**: PNG, JPEG, GIF, WebP.
* **Execution**: Pass files into the TUI using `@<filename>`, via clipboard paste, or by appending the `-f <filename>` flag in CLI mode.

### PDF Pipeline (NixOS)
* **System Dependency**: Add `poppler_utils` to `environment.systemPackages` within `configuration.nix`.
* **Standard Input Piping**: Define a shell alias to extract text and pipe it to the agent context:
  `alias ocread="pdftotext $1 - | opencode run -f -"`
* **Plugin Implementation**: For automated ingestion, develop a Node.js module utilizing `pdf-parse`. Place the compiled script in `~/.config/opencode/plugins/` to hook into the standard file load execution path.

## 2. Custom Command Architecture
Global constraints are managed by `AGENTS.md`. Atomic, repeatable operations must be defined as custom commands to enforce strict parameters for physics solver development.

* **Directory**: `.opencode/commands/`
* **Function**: Standardizes queries for C++ memory safety checks and Python (JAX) computational efficiency profiling.

**Implementation Example: `.opencode/commands/optimize_matrix.md`**
```markdown
---
description: "Analyze JAX/C++ solver for loop vectorization and O notation efficiency."
---
Review $arguments for memory bottlenecks.
Critique code based on efficiency and memory safety.
Prioritize vectorized matrix operations over iterative loops.
Justify critiques with computational constraints (O notation).
```
Execution in TUI: `/optimize_matrix solver.cpp`

## 3. Internal Vim Navigation (TUI)
To maintain keystroke continuity with Neovim, configure the OpenCode TUI to override default readline (Emacs) bindings.

### Configuration modification
Append the keybindings parameter in `~/.config/opencode/opencode.json`:
```json
{
  "ui": {
    "keybindings": "vim",
    "scroll_speed": 3
  }
}
```

### Operation Mechanics
* **Input/Normal Mode Toggle**: Use `Esc` to drop out of the prompt input into Normal Mode.
* **Menu/Buffer Navigation**: Use `j` and `k` to traverse chat context buffers or select agents from dropdown menus.
* **Context Search**: Use `/` in Normal Mode to search the active TUI chat buffer.
* **Slash Commands**: Trigger OpenCode internal commands (e.g., `/init`, `/clear`) directly from Insert Mode or map them to Neovim-style command mode keystrokes if the terminal emulator intercepts standard inputs.
