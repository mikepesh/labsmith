# LabSmith

A Cowork plugin that builds hands-on training modules from vendor PDFs. Convert docs once, generate as many lab exercises as you need — each grounded in the actual product documentation.

> **Built with AI.** I'm a presales engineer, not a developer. LabSmith was designed, built, and documented with heavy assistance from Claude (Anthropic). The architecture decisions are mine, the domain expertise is mine, but the Python, the shell scripts, and a good chunk of the problem-solving happened through conversation with an AI. If I can build this, you can too.

## Quick start

```bash
git clone https://github.com/mikepesh/labsmith.git ~/Documents/labsmith
cd ~/Documents/labsmith
bash labsmith.sh
```

`labsmith.sh` is a tiny bootstrap (silent if everything is ready): it ensures **Python 3.9+**, `marker/venv/` with **pymupdf4llm** and **Textual**, then starts the **terminal UI** — menus for convert, chunk, query, tests, and setup info. Use `bash labsmith.sh --db other.db` for a non-default database.

Optional: `bash setup.sh` for the older install-and-verify shell flow; `bash scripts/labsmith-wizard.sh` for the legacy interactive bash wizard.

Then install `labsmith.plugin` in Claude Desktop.

Full setup, usage, and best practices: **[USER-GUIDE.md](USER-GUIDE.md)**

Try it out, break it, tell me what sucks: **[Open an issue](https://github.com/mikepesh/labsmith/issues)**
