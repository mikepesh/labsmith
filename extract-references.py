#!/usr/bin/env python3
"""
Reference Library Extractor
Splits large FortiOS reference markdown files into per-topic snippets.

Usage:
    python3 extract-references.py <input.md> <output-dir> [--prefix cli|admin]

Examples:
    python3 extract-references.py FortiOS-7.6.6-CLI_Reference.md references/fortios-7.6/ --prefix cli
    python3 extract-references.py FortiOS-7.6.6-Administration_Guide.md references/fortios-7.6/ --prefix admin
"""

import sys
import re
from pathlib import Path

def slugify(text):
    """Convert heading text to a filename-safe slug."""
    text = text.lower().strip()
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[\s_]+', '-', text)
    text = re.sub(r'-+', '-', text)
    return text.strip('-')

def extract_sections(content, min_lines=10):
    """Split markdown content into sections based on top-level headings."""
    sections = []
    current_heading = None
    current_lines = []

    for line in content.split('\n'):
        # Match h1 or h2 headings (# or ##)
        heading_match = re.match(r'^(#{1,2})\s+(.+)$', line)

        if heading_match:
            # Save previous section if it has content
            if current_heading and len(current_lines) >= min_lines:
                sections.append({
                    'heading': current_heading,
                    'content': '\n'.join(current_lines)
                })

            current_heading = heading_match.group(2).strip()
            current_lines = [line]
        else:
            current_lines.append(line)

    # Don't forget the last section
    if current_heading and len(current_lines) >= min_lines:
        sections.append({
            'heading': current_heading,
            'content': '\n'.join(current_lines)
        })

    return sections

def extract_config_blocks(content):
    """
    For FortiOS CLI references: split into logical groups.
    
    Three types of content:
    1. Config categories: ## **firewall** (single word, groups all config firewall xxx)
    2. Diagnose commands: ## **diagnose xxx** (grouped by first sub-word)
    3. Execute commands: ## **execute xxx** (grouped by first sub-word)
    
    Config sub-blocks (## **config firewall policy**) stay inside their parent category.
    Diagnose/execute sub-commands stay inside their parent group.
    """
    lines = content.split('\n')
    sections = []
    current_heading = None
    current_type = None  # 'config', 'diagnose', 'execute'
    current_group = None  # the grouping key
    current_lines = []

    # Known intro headings to skip
    skip_headings = {
        'fortios cli reference', 'availability of commands and options',
        'fortigate model', 'hardware configuration', 'command tree',
        'cli configuration commands'
    }

    def save_current():
        if current_heading and len(current_lines) > 3:
            sections.append({
                'heading': current_heading,
                'content': '\n'.join(current_lines)
            })

    for line in lines:
        heading_match = re.match(r'^##\s+\*\*([^*]+)\*\*\s*$', line)

        if not heading_match:
            current_lines.append(line)
            continue

        heading_text = heading_match.group(1).strip()
        heading_lower = heading_text.lower()

        # Skip intro headings
        if heading_lower in skip_headings or 'fortigate' in heading_lower or 'fortios' in heading_lower:
            current_lines.append(line)
            continue

        # Determine what type of heading this is
        if heading_lower.startswith('config '):
            # Config sub-block — stays in current config category section
            current_lines.append(line)

        elif heading_lower.startswith('diagnose '):
            # Get the top-level diagnose group (first word after diagnose)
            parts = heading_lower.split()
            group_key = parts[1] if len(parts) > 1 else 'general'

            if current_type == 'diagnose' and current_group == group_key:
                # Same diagnose group — append
                current_lines.append(line)
            else:
                # New diagnose group
                save_current()
                current_heading = f"diagnose {group_key}"
                current_type = 'diagnose'
                current_group = group_key
                current_lines = [line]

        elif heading_lower.startswith('execute '):
            # Get the top-level execute group (first word after execute)
            parts = heading_lower.split()
            group_key = parts[1] if len(parts) > 1 else 'general'

            if current_type == 'execute' and current_group == group_key:
                # Same execute group — append
                current_lines.append(line)
            else:
                # New execute group
                save_current()
                current_heading = f"execute {group_key}"
                current_type = 'execute'
                current_group = group_key
                current_lines = [line]

        else:
            # Top-level config category (single word like "firewall", "system", "vpn")
            save_current()
            current_heading = heading_text
            current_type = 'config'
            current_group = heading_lower
            current_lines = [line]

    # Don't forget the last section
    save_current()

    return sections

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 extract-references.py <input.md> <output-dir> [--prefix cli|admin]")
        print("")
        print("Examples:")
        print("  python3 extract-references.py FortiOS-7.6.6-CLI_Reference.md refs/ --prefix cli")
        print("  python3 extract-references.py FortiOS-7.6.6-Administration_Guide.md refs/ --prefix admin")
        sys.exit(1)

    input_file = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])
    prefix = "ref"

    if "--prefix" in sys.argv:
        idx = sys.argv.index("--prefix")
        if idx + 1 < len(sys.argv):
            prefix = sys.argv[idx + 1]

    if not input_file.exists():
        print(f"Error: {input_file} not found")
        sys.exit(1)

    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Reading: {input_file}")
    content = input_file.read_text(encoding='utf-8')
    total_lines = len(content.split('\n'))
    print(f"Total lines: {total_lines}")

    # Use config block extraction for CLI references, section extraction for others
    if prefix == "cli":
        print("Mode: CLI Reference (splitting by config blocks)")
        sections = extract_config_blocks(content)
    else:
        print("Mode: General (splitting by headings)")
        sections = extract_sections(content)

    if not sections:
        print("No sections found. Try a different prefix or check the file format.")
        sys.exit(1)

    print(f"Found {len(sections)} sections")
    print("")

    # Write each section to its own file
    written = 0
    manifest = []

    for section in sections:
        slug = slugify(section['heading'])
        if not slug:
            continue

        filename = f"{prefix}-{slug}.md"
        filepath = output_dir / filename
        line_count = len(section['content'].split('\n'))

        filepath.write_text(section['content'], encoding='utf-8')
        written += 1
        manifest.append({
            'file': filename,
            'heading': section['heading'],
            'lines': line_count
        })
        print(f"  ✅ {filename} ({line_count} lines)")

    # Write manifest
    manifest_path = output_dir / f"{prefix}-manifest.md"
    manifest_lines = [f"# {prefix.upper()} Reference Manifest\n"]
    manifest_lines.append(f"Source: {input_file.name}\n")
    manifest_lines.append(f"Extracted: {written} sections\n\n")
    manifest_lines.append("| File | Section | Lines |")
    manifest_lines.append("|------|---------|-------|")
    for entry in manifest:
        manifest_lines.append(f"| {entry['file']} | {entry['heading']} | {entry['lines']} |")

    manifest_path.write_text('\n'.join(manifest_lines), encoding='utf-8')

    print("")
    print(f"Written: {written} files to {output_dir}/")
    print(f"Manifest: {manifest_path}")

    # Show module-to-reference mapping hint
    print("")
    print("=== Suggested Module Mappings ===")
    for entry in manifest:
        heading_lower = entry['heading'].lower()
        modules = []
        if 'interface' in heading_lower or 'zone' in heading_lower:
            modules.append("Module 02")
        if 'firewall' in heading_lower or 'policy' in heading_lower:
            modules.append("Module 03")
        if 'nat' in heading_lower or 'vip' in heading_lower:
            modules.append("Module 03")
        if 'route' in heading_lower or 'ospf' in heading_lower or 'bgp' in heading_lower:
            modules.append("Module 04")
        if 'switch' in heading_lower or 'fortilink' in heading_lower:
            modules.append("Module 05")
        if 'wireless' in heading_lower or 'wtp' in heading_lower or 'ssid' in heading_lower or 'ap' in heading_lower:
            modules.append("Module 06")
        if 'vpn' in heading_lower or 'ipsec' in heading_lower or 'ssl' in heading_lower:
            modules.append("Module 07")
        if 'antivirus' in heading_lower or 'ips' in heading_lower or 'webfilter' in heading_lower or 'profile' in heading_lower:
            modules.append("Module 08")
        if 'system' in heading_lower and ('dns' in heading_lower or 'ntp' in heading_lower or 'global' in heading_lower):
            modules.append("Module 01")

        if modules:
            print(f"  {entry['file']} → {', '.join(modules)}")

if __name__ == "__main__":
    main()
