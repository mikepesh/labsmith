# LabSmith

A Cowork plugin that builds hands-on training modules from vendor PDFs. Convert docs once, generate as many lab exercises as you need — each grounded in the actual product documentation.

> **Built with AI.** I'm a presales engineer, not a developer. LabSmith was designed, built, and documented with heavy assistance from Claude (Anthropic). The architecture decisions are mine, the domain expertise is mine, but the Python, the shell scripts, and a good chunk of the problem-solving happened through conversation with an AI. If I can build this, you can too.

## Quick start

```bash
git clone https://github.com/mikepesh/labsmith.git ~/Documents/labsmith
cd ~/Documents/labsmith
bash labsmith.sh
```

The wizard walks through prerequisites (Python, git, PDF stack) and the rest of the pipeline — same checks as `setup.sh`, which lives on for an optional install-and-verify-only pass if you prefer that first.

**Experimental:** A Textual terminal UI lives under `tui/` for trying out menu-driven convert/chunk/query. It is **not** the default workflow. From the repo root: `bash scripts/labsmith-tui.sh` (installs `textual` into `marker/venv/` on first run).

Then install `labsmith.plugin` in Claude Desktop.

Full setup, usage, and best practices: **[USER-GUIDE.md](USER-GUIDE.md)**

Try it out, break it, tell me what sucks: **[Open an issue](https://github.com/mikepesh/labsmith/issues)**
