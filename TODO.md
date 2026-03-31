# LabSmith — Known Issues & Future Work

## Chunker: title quality

**Problem**: The FortiOS Admin Guide markdown has CLI command examples rendered as headings. The chunker splits on h1–h3, so these become chunk titles.

**Impact**: 1,528 of 1,653 chunks (92%) have CLI-command titles like `diagnose debug enable`. Only 22 chunks have meaningful bold section titles like `**Getting started**` or `**Policy and Objects**`.

**Doesn't block**: Module generation still works — search by keyword hits content, and bold-titled chunks serve as major section landmarks.

**Fix direction**: Teach the chunker to detect CLI-looking headings and either skip them (merge into parent chunk) or prefer the nearest bold-text title as the section_title. Could also pre-process the markdown to demote CLI headings before chunking.
