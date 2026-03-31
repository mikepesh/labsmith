# Module 02 — FortiOS CLI Basics

**Workshop:** Cisco to Fortinet Migration
**Estimated Time:** 45 minutes
**Prerequisites:** Module 00 (Pre-Lab Setup & Orientation)

---

## Overview

This module builds CLI fluency for engineers coming from Cisco IOS. Where IOS uses a modal hierarchy (User EXEC → Privileged EXEC → Global Config → Sub-Config), FortiOS uses a flat command tree that you navigate into with `config`, modify with `set`, and commit with `end`. The differences are small but they compound quickly — muscle memory from IOS will mislead you in the first hour if you do not recalibrate it here.

By the end of this module you will move through FortiOS configuration objects as confidently as you move through IOS mode transitions today. You will also build a personal cheat sheet of the `get`, `show`, `diagnose`, and `execute` commands that replace your most-used IOS equivalents.

This is a hands-on module. Every concept is followed by a lab step where you run the command on the FG-121G and observe the output.

---

## Learning Objectives

By the end of this module you will be able to:

- Explain the structural differences between FortiOS CLI and Cisco IOS CLI
- Navigate FortiOS configuration trees using `config`, `edit`, `next`, and `end`
- Use `get`, `show`, `diagnose`, and `execute` to retrieve system state and perform operational tasks
- Map your 15 most-used Cisco IOS commands to their FortiOS equivalents
- Modify and commit configuration changes without relying on a `write memory` step
- Recover from a configuration mistake using `unset` and `delete` instead of `no`

---

## Conceptual Overview

### The Mental Model Shift

On Cisco IOS you think in **modes**. You enter a mode, the prompt changes, and you are restricted to that mode's command set until you exit. Configuration is staged in running-config and only persists when you explicitly save.

On FortiOS you think in **trees**. There are no modes — you navigate into a configuration object path (`config system interface`, `config firewall policy`), make changes, and type `end`. The moment you type `end`, the change is live and saved to flash. There is no separate running-config vs. startup-config.

This has two practical consequences:

1. **There is no safety net.** On IOS you can make changes and revert by reloading without saving. On FortiOS, `end` = committed. If you make a mistake, you must go back in and fix it manually.

2. **There is no `no` command.** IOS negates a line with `no <line>`. FortiOS uses `unset <attribute>` to clear a single value back to default, or `delete <object-id>` to remove an entire object (like a firewall policy entry).

### Terminology Mapping

| Cisco IOS Term | FortiOS Equivalent | Notes |
|---|---|---|
| User EXEC mode | N/A | FortiOS has no restricted mode — you log in with full access |
| Privileged EXEC (`enable`) | Default CLI prompt | The `admin` account with `super_admin` profile has immediate full access |
| Global config (`conf t`) | `config <section>` | No global mode — you go directly to the section you need |
| Sub-config (e.g., `interface Gi0/1`) | `edit <object>` inside a `config` block | `edit` selects a specific entry within a config section |
| `show running-config` | `show full-configuration` | Dumps the full config as it would appear in a backup file |
| `show` (various) | `get` | `get system status`, `get system interface`, etc. |
| `debug` | `diagnose` | `diagnose debug`, `diagnose sniffer`, etc. |
| `copy`, `ping`, `reload` | `execute` | Operational commands: `execute ping`, `execute reboot`, `execute cfg save` |
| `write memory` | Automatic | Config saves to flash on `end` — no manual save needed |
| `no <command>` | `unset <attribute>` / `delete <id>` | `unset` clears a value; `delete` removes an object |
| Running-config vs. startup-config | Single config (always saved) | No dual-config model — what you set is what persists |

### The Four Top-Level Command Families

Every FortiOS CLI command starts with one of four verbs. If you remember nothing else from this module, remember this table.

| Verb | Purpose | When You Use It | Cisco Analogy |
|---|---|---|---|
| `config` | Enter a configuration tree to create or modify objects | Changing settings | `configure terminal` |
| `get` | Read current configuration or system state | Checking what is configured or what is happening | `show` |
| `show` | Display configuration as it would appear in a backup file | Reviewing or exporting config | `show running-config` |
| `execute` | Run an operational command that takes immediate action | Pinging, rebooting, saving, uploading firmware | `ping`, `reload`, `copy` |
| `diagnose` | Low-level diagnostics and debug | Troubleshooting packet flow, CPU, sessions | `debug`, `show tech-support` |

> **Tip:** `get` and `show` look similar. The rule of thumb: `get` gives you live state and parsed output. `show` gives you the raw config syntax you could paste into another device.

---

## Command Reference Table

| Task | Cisco IOS | FortiOS |
|---|---|---|
| Check firmware version and serial | `show version` | `get system status` |
| Show full running config | `show running-config` | `show full-configuration` |
| Show interface status (link/speed) | `show interfaces status` | `get system interface physical` |
| Show IP addresses on interfaces | `show ip interface brief` | `get system interface` |
| Show routing table | `show ip route` | `get router info routing-table all` |
| Show ARP table | `show ip arp` | `get system arp` |
| Ping a host | `ping <ip>` | `execute ping <ip>` |
| Traceroute | `traceroute <ip>` | `execute traceroute <ip>` |
| Save configuration | `write memory` | `execute cfg save` (usually unnecessary — auto-saves) |
| Reboot | `reload` | `execute reboot` |
| Factory reset | `write erase` + `reload` | `execute factoryreset` |
| Enter config for an interface | `interface GigabitEthernet0/1` | `config system interface` then `edit port1` |
| Remove a config attribute | `no <command>` | `unset <attribute>` |
| Delete a config object | `no <object>` | `delete <id>` |
| Check CPU and memory | `show processes cpu` / `show memory` | `get system performance status` |

---

## Lab Exercise

### Part 1 — Verify System Status

Connect to the FG-121G via console (9600-8-N-1). Log in as `admin` (blank password unless changed in Module 01).

1. Check the firmware version and hardware serial:

```
get system status
```
<!-- Equivalent: show version -->

2. Check CPU and memory usage:

```
get system performance status
```
<!-- Equivalent: show processes cpu / show memory statistics -->

3. View all physical interface states:

```
get system interface physical
```
<!-- Equivalent: show interfaces status -->

#### Verification

You should see:

- FortiOS version `v7.6.6`
- Serial number starting with `FG121G`
- CPU usage under 10% (idle lab)
- port1 through port16 listed, plus FortiLink SFP+ ports
- mgmt interface with link status

---

### Part 2 — Navigate a Configuration Tree

1. Enter the system global configuration:

```
config system global
```

Notice the prompt changes:

```
FG-121G (global) #
```

2. View what attributes are available:

```
get
```

This lists all attributes in the current config tree with their current values.

3. Check the current hostname:

```
get hostname
```

4. Change the hostname (temporarily — we will change it back):

```
set hostname CLI-TEST
```

Notice the prompt updates immediately:

```
CLI-TEST (global) #
```

5. Commit and exit:

```
end
```

The prompt returns to:

```
CLI-TEST #
```

> **Key point:** The hostname changed the moment you typed `end`. There was no `write memory`. This is now saved to flash.

6. Change it back:

```
config system global
    set hostname FG-121G-LAB
end
```

#### Verification

```
get system status | grep Hostname
```

Expected output:

```
Hostname              : FG-121G-LAB
```

---

### Part 3 — The `get` vs. `show` Difference

1. Run `get` on the mgmt interface:

```
get system interface mgmt
```

This returns a parsed, human-readable view of the interface configuration.

2. Now run `show` on the same interface:

```
show system interface mgmt
```

This returns the raw config syntax — the exact lines you would paste into another FortiGate to recreate this interface.

3. Compare the two outputs. Note that `get` includes live state (link status, IP, MAC) while `show` only includes configured attributes.

#### Verification

- `get` output includes fields like `link`, `speed`, `mac` that do not appear in `show`
- `show` output is formatted as `config`/`edit`/`set`/`end` blocks

---

### Part 4 — Operational Commands with `execute`

1. Ping the management gateway (or your laptop if connected via mgmt):

```
execute ping 192.168.1.100
```
<!-- Equivalent: ping 192.168.1.100 -->

2. Check the ARP table:

```
get system arp
```
<!-- Equivalent: show ip arp -->

3. View the routing table:

```
get router info routing-table all
```
<!-- Equivalent: show ip route -->

4. Force an explicit config save (normally unnecessary but good to know):

```
execute cfg save
```
<!-- Equivalent: write memory -->

#### Verification

- Ping returns replies (if your laptop is on 192.168.1.0/24 network)
- ARP table shows at least the management gateway
- Routing table shows connected routes for any configured interfaces

---

### Part 5 — Diagnose and Debug

1. View active sessions (firewall session table):

```
diagnose sys session stat
```
<!-- Equivalent: show conn count (ASA) -->

2. Start a packet sniffer on the mgmt interface:

```
diagnose sniffer packet mgmt 'icmp' 4 5
```

This captures 5 ICMP packets on the mgmt interface with verbose output (level 4).

3. From your laptop, ping the FortiGate mgmt IP. You should see the packets appear in the sniffer output.

4. Press `Ctrl+C` to stop the sniffer if it does not stop after 5 packets.

> **Cisco equivalent:** `debug ip icmp` or `capture` on ASA. The FortiOS sniffer is closer to ASA's `capture` — it uses tcpdump-style BPF filters.

#### Verification

- `diagnose sys session stat` returns session counts (may be zero or low in an idle lab)
- Sniffer shows ICMP echo request/reply with source and destination IPs, TTL, and packet length

---

### Part 6 — Undoing Mistakes (No `no` Command)

1. Enter the mgmt interface config and set a description:

```
config system interface
    edit mgmt
        set description "Lab management interface"
    end
```

2. Verify:

```
get system interface mgmt | grep description
```

3. Now remove the description using `unset`:

```
config system interface
    edit mgmt
        unset description
    end
```

4. Verify it is gone:

```
get system interface mgmt | grep description
```

The description field should be empty or absent.

> **Key takeaway:** Where Cisco uses `no description`, FortiOS uses `unset description`. Where Cisco uses `no interface Loopback0` or `no ip access-list`, FortiOS uses `delete` within the relevant config tree.

#### Verification

- After step 2, description shows `Lab management interface`
- After step 4, description is blank/default

---

## Instructor Notes

### Talking Points

- The biggest stumbling block for Cisco engineers is the auto-save behavior. Reinforce this multiple times: `end` = committed. There is no undo-by-reload safety net.
- The `no` command reflex is deeply ingrained. Spend extra time on Part 6 — have learners practice `unset` and `delete` until it feels natural.
- Point out that `get` is their new best friend. It replaces most `show` commands from IOS. The FortiOS `show` command is specifically for config export, not status checking.
- The four command families (`config`, `get`, `show`, `execute`, `diagnose`) map cleanly to mental categories. Encourage learners to think "what verb do I need?" before typing.

### Common Mistakes

- **Typing `conf t`** — FortiOS does not have a global config mode. You must specify the tree: `config system global`, `config system interface`, etc. `conf t` returns an error.
- **Typing `no` to remove something** — Returns a syntax error. Must use `unset` (clear attribute) or `delete` (remove object).
- **Forgetting that `end` saves** — Learners may type `end` thinking they can review and save later. The change is already live.
- **Confusing `get` and `show`** — `get system interface` shows live state. `show system interface` shows raw config. They return different information.
- **Using `exit` instead of `end`** — In nested config blocks, `exit` goes up one level but does NOT save. `end` commits everything and returns to root. If learners use `exit` at the wrong level, they may not realize their changes were not committed.

### Anticipated Questions and Answers

**Q: Is there a way to preview changes before committing?**
A: Not natively in the same way IOS does. You can review what you have set inside a config block with `get` before typing `end`. For critical production changes, use config revisions (`execute revision diff`) to compare before and after.

**Q: Can I revert to a previous configuration?**
A: Yes. FortiOS keeps config revisions. Use `execute revision list` to see them and `execute revision revert <id>` to roll back. This is more powerful than IOS's approach but most engineers do not discover it until they need it.

**Q: What about context-sensitive help? Does `?` work?**
A: Yes, identically to IOS. Type `?` at any point to see available commands or arguments. Tab completion also works.

**Q: Is there a FortiOS equivalent of `show tech-support`?**
A: `diagnose debug report` generates a comprehensive diagnostic bundle. You can also use `execute tac report` to generate a TAC-ready support file. <!-- VERIFY: "exact command syntax for tac report in 7.6.6" -->

**Q: Can I pipe output like in IOS (`| include`, `| begin`)?**
A: Yes. FortiOS supports `| grep` (not `| include`). Example: `get system status | grep Version`. You can also use `| grep -f` for case-insensitive matching.

### Time Management Tips

- **Part 1 (5 min):** Quick verification — do not linger. If learners can run `get system status` they are good.
- **Part 2 (10 min):** This is the core exercise. Give learners time to experiment with entering and exiting config trees. Let them try wrong commands and discover the error messages.
- **Part 3 (5 min):** Brief but important conceptual distinction. Show both outputs side by side.
- **Part 4 (5 min):** Quick operational commands. Skip traceroute if time is tight — ping and ARP are sufficient.
- **Part 5 (10 min):** The sniffer is a crowd-pleaser with Cisco engineers. Let them experiment with different BPF filters if they finish early.
- **Part 6 (10 min):** Critical for muscle memory retraining. Do not rush this. Have learners set, verify, unset, and verify again at least twice.
- **If running behind:** Cut Part 4 to just ping and Part 5 to just viewing session stats (skip the live sniffer). Do not cut Part 6.
