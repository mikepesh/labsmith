# LabSmith Module Format Reference

This document defines the canonical structure for LabSmith workshop modules. Every module follows this format.

## File naming

`Module-<NN>-<Title-Slug>.md`

Examples:

- `Module-00-PreLab.md`
- `Module-01-FortiGate-Initial-Setup.md`
- `Module-05-FortiLink-Managed-Switches.md`

## Frontmatter

Every module starts with:

```markdown
# Module <NN> — <Title>

**Workshop:** <full workshop name>
**Estimated Time:** <duration>
**Prerequisites:** <module dependencies or "None">
```

## Required sections (in order)

### Overview

2-3 paragraphs explaining what this module covers and why it matters. Set expectations for what the learner will be able to do afterward.

### Learning Objectives

Bulleted list starting with "By the end of this module you will be able to:" followed by 4-6 measurable objectives using action verbs (configure, verify, explain, troubleshoot).

### Conceptual Overview

Technical explanation of the topic. If the workshop targets engineers migrating from another platform, include:

- A mental model comparison (how the old platform handles this vs. the new one)
- A terminology mapping table: Old Term | New Term | Notes

### Command Reference Table

8-15 rows covering the most common operations for this topic.
Columns: Task | Old CLI (if applicable) | New CLI

### Lab Exercise

Numbered Parts (Part 1, Part 2, etc.). Each Part contains:

- Numbered steps with CLI command blocks
- If migration context: `# Equivalent: <old platform command>` below each command
- A **Verification** subsection at the end with `show`/`get`/`diagnose` commands and expected output

### Instructor Notes

Four subsections:

- **Talking Points** — key messages to emphasize
- **Common Mistakes** — what learners typically get wrong and how to help
- **Anticipated Questions and Answers** — 3-5 likely questions with prepared answers
- **Time Management Tips** — pacing guidance, where to spend vs. skip time

## Quality markers

- Total length: 300-600 lines (under 100 = incomplete)
- Every CLI command sourced from reference docs or marked with `<!-- VERIFY: "description" -->`
- No hardcoded values that should be environment-specific
- Clear, direct tone — assumes technical competence
