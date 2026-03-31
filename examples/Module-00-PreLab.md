# Module 00 — Pre-Lab Setup & Orientation

**Workshop:** Fortinet Security Fabric — Hands-On Transition Training
**Platform:** FortiOS 7.6.6
**Audience:** Cisco-experienced engineers (CCNA–CCNP level)
**Document Reference:** FortiOS 7.6.6 CLI Reference (2026-01-28), FortiOS 7.6.6 Release Notes (2026-03-09)

---

## Overview

This pre-lab module orients you to the lab environment before any hands-on configuration begins. You will verify physical hardware, establish console access, learn how the FortiOS CLI differs from Cisco IOS, and confirm each device is at a known-good factory-default state.

No prior Fortinet experience is assumed. If you can navigate a Cisco router or switch CLI, you already have the foundational mental model needed — this module maps what you know to how Fortinet does it.

---

## Learning Objectives

By the end of this module you will be able to:

- Identify each physical device in the lab rack and describe its role in the Fortinet Security Fabric
- Establish a console session on the FortiGate, FortiSwitch Core, and FortiSwitch Access layers
- Navigate the FortiOS CLI and relate its structure to Cisco IOS command equivalents
- Perform a verified factory reset of the FortiGate FG-121G
- Confirm each device is running FortiOS 7.6.6 (FortiGate) and is at a clean starting state

---

## Lab Hardware

### Equipment Inventory

| Device | Model | Role | OS |
|---|---|---|---|
| FortiGate | FG-121G | Next-generation firewall / Security Fabric root / wireless controller | FortiOS 7.6.6 |
| FortiSwitch Core | FS-1024E | Data-center-class core switch (FortiLink managed) | FortiSwitchOS |
| FortiSwitch Access (ToR) | FS-448E | Top-of-rack access switch, no PoE (FortiLink managed) | FortiSwitchOS |
| FortiSwitch Access (PoE) | FS-448E-FPOE | Access layer switch, full 802.3af/at PoE (FortiLink managed) | FortiSwitchOS |
| FortiAP | FAP-441K | Wi-Fi 7 access point — 4 radios including dedicated scanning (CAPWAP managed) | FortiAP |

### Key Hardware Specs (Reference)

**FG-121G — FortiGate**

| Specification | Value |
|---|---|
| Console port | RJ45 (rear panel) |
| Management port | 10/100/1000 RJ45, labeled **mgmt** |
| HA port | RJ45, labeled **ha** |
| LAN ports | port1–port16 (16x GE RJ45) |
| FortiLink ports | 4x 10GE SFP+ (dedicated, front panel) |
| Additional SFP ports | 8x GE SFP |
| Internal storage | 480 GB SSD |
| License | Enterprise Protection (all FortiGuard services active) |
| Max FortiSwitches | 48 |
| Max FortiAPs | 128 |

**FS-1024E — Core Switch**

| Specification | Value |
|---|---|
| Console port | RJ45 |
| Management port | 1x RJ45 |
| Data ports | 24x 10GE SFP+/SFP |
| Uplink ports | 2x 100GE QSFP28/QSFP+ |
| Switching capacity | 880 Gbps |
| Power | Dual hot-swap AC PSU, front-to-back airflow |
| Form factor | 1RU |

**FS-448E — ToR Access Switch (no PoE)**

| Specification | Value |
|---|---|
| Console port | RJ45 |
| Data ports | 48x GE RJ45 + 4x 10GE SFP+ |
| Switching capacity | 176 Gbps |
| Power | Single PSU |

**FS-448E-FPOE — PoE Access Switch**

| Specification | Value |
|---|---|
| Console port | RJ45 |
| Data ports | 48x GE RJ45 + 4x 10GE SFP+ |
| PoE | 48-port 802.3af/at, 772 W total budget |
| Switching capacity | 176 Gbps |
| Max power draw | 921.4 W |

**FAP-441K — Wi-Fi 7 Access Point**

| Specification | Value |
|---|---|
| Wi-Fi generation | Wi-Fi 7 (802.11be) |
| Radios | R1: 2.4 GHz 4×4, R2: 5 GHz 4×4, R3: 6 GHz 4×4, R4: dedicated scanning 2×2 |
| LAN ports | LAN1: 10G MultiGig (802.3bt PoE in), LAN2: 10G MultiGig (802.3at) |
| Full power requires | 802.3bt (41.7 W) — PoE+ (802.3at) puts AP in degraded mode (17 dBm / 2×2 chains only) |
| Management | CAPWAP to FortiGate (integrated wireless controller) |

---

### Physical Topology

```
                    ┌─────────────────────────────┐
                    │         INTERNET / WAN       │
                    │     (simulated upstream)     │
                    └───────────────┬─────────────┘
                                    │ port1 (WAN)
                    ┌───────────────┴─────────────┐
                    │          FG-121G             │
                    │       FortiGate NGFW         │
                    │   Security Fabric Root       │
                    │   Wireless LAN Controller    │
                    └──────────┬──────────────────┘
                               │ 4x 10GE SFP+ FortiLink
                    ┌──────────┴──────────────────┐
                    │          FS-1024E            │
                    │      Core Switch (L2/L3)     │
                    │    FortiLink Managed         │
                    └────────┬────────────┬────────┘
                             │ 10GE       │ 10GE
              ┌──────────────┴──┐    ┌───┴──────────────┐
              │   FS-448E        │    │  FS-448E-FPOE     │
              │ ToR Access (no PoE)│  │ PoE Access Layer  │
              │ FortiLink Managed│    │ FortiLink Managed │
              └──────────────────┘    └────────┬──────────┘
                                               │ 802.3bt PoE
                                      ┌────────┴──────────┐
                                      │     FAP-441K       │
                                      │  Wi-Fi 7 AP        │
                                      │ CAPWAP to FG-121G  │
                                      └───────────────────┘
```

> **Cisco Parallel:** Think of the FG-121G as your ASA + Catalyst WLC + router in a single box. FortiLink is roughly analogous to Cisco Catalyst Center (DNA Center) managing switches — except FortiLink is built directly into FortiOS and requires no separate controller appliance.

---

### Lab IP Address Plan

The following addressing will be used throughout all modules. Do not configure these addresses yet — each module builds on the previous.

| Segment | Network | VLAN | Notes |
|---|---|---|---|
| OOB Management | 192.168.1.0/24 | — | FG-121G mgmt port: .1, instructor laptop: .100 |
| WAN (simulated) | 203.0.113.0/30 | — | port1 WAN uplink; .1 = upstream router, .2 = FG-121G |
| VLAN 10 — Corporate LAN | 10.10.10.0/24 | 10 | User workstations |
| VLAN 20 — Servers | 10.10.20.0/24 | 20 | Lab server segment |
| VLAN 30 — Wireless | 10.10.30.0/24 | 30 | FAP-441K clients |
| VLAN 99 — Infrastructure Mgmt | 10.10.99.0/24 | 99 | In-band FortiSwitch/FortiAP management |
| FortiLink internal | 169.254.0.0/24 | — | Auto-assigned by FortiGate; do not configure manually |

---

## FortiOS CLI Orientation

### How FortiOS CLI Differs From Cisco IOS

If you have ever typed `conf t` on a Cisco device, the FortiOS CLI will feel familiar in structure but different in syntax. Here is what you need to know before touching anything.

**Modes: There are no named modes with different prompts like EXEC vs. Config.**
FortiOS uses a flat command tree. You navigate into configuration objects with `config`, then `edit` specific entries, then `end` when done. The prompt changes to reflect your depth in the tree, but you are not "locked" to a mode the way IOS is.

**Auto-save: FortiOS saves to flash automatically.**
There is no `write memory` or `copy running-config startup-config`. Your changes take effect and persist the moment you type `end`. You can force an immediate save with `execute cfg save` if needed, but it is not normally required.

**No enable mode.** You log in directly to the operational CLI. Admin accounts with the `super_admin` profile (the default `admin` account) have full access immediately.

**Tab completion and `?` work exactly as expected.**
Type a partial command and press Tab to complete. Type `?` to see available options at any point. This works even mid-command.

---

### CLI Command Structure

```
# Navigate into a configuration tree
config <section>
    edit <object-name-or-id>
        set <attribute> <value>
        set <attribute> <value>
    next                          ← move to next object without exiting
    end                           ← commit and exit this config tree
```

Example — set the hostname:

```
config system global
    set hostname FG-121G-LAB
end
```

There is no equivalent of Cisco's `(config)#` prompt. You know you are inside a config tree because the prompt changes:

```
FG-121G-LAB # config system global
FG-121G-LAB (global) # set hostname MyGate
MyGate (global) # end
MyGate #
```

---

### Cisco IOS to FortiOS Command Mapping

| What You Want to Do | Cisco IOS | FortiOS 7.6.6 |
|---|---|---|
| Check software version and serial | `show version` | `get system status` |
| Show running configuration | `show running-config` | `show full-configuration` |
| Show interface status | `show interfaces status` | `get system interface physical` |
| Show IP address on interface | `show ip interface brief` | `get system interface` |
| Show routing table | `show ip route` | `get router info routing-table all` |
| Show ARP table | `show ip arp` | `get system arp` |
| Ping | `ping <ip>` | `execute ping <ip>` |
| Traceroute | `traceroute <ip>` | `execute traceroute <ip>` |
| Save configuration | `write memory` | `execute cfg save` (or it auto-saves) |
| Reload/reboot device | `reload` | `execute reboot` |
| Factory reset | `write erase` + reload | `execute factoryreset` |
| Enter privileged exec | `enable` | N/A — you are always at this level |
| Enter config mode | `configure terminal` | Begin typing `config <section>` |
| Exit config mode | `exit` or `end` | `end` |
| Abort without saving | `Ctrl+Z` | `abort` or navigate up with `end` (changes save on `end`) |
| Show MAC address table | `show mac address-table` | `get switch mac-address-table` (on FortiSwitch) |
| Show CDP neighbors | `show cdp neighbors` | `get system fortiguard-service` / FortiLink topology view |

> **Important difference:** In FortiOS, `end` always commits and saves your changes. If you make a mistake inside a config block and want to undo, you must re-enter the block and manually correct the values. There is no `no` command equivalent — instead you either `unset <attribute>` to remove a value or `delete <object>` to remove an object entirely.

---

### The Four Top-Level Command Types

| Type | Purpose | Cisco Analogy |
|---|---|---|
| `config` | Enter a configuration tree to create/modify objects | `configure terminal` |
| `get` | Display current configuration or system state (read-only) | `show` |
| `show` | Display configuration as it would appear in a backup (read-only) | `show running-config` |
| `diagnose` | Low-level diagnostic and debug commands | `debug`, `show tech-support` |
| `execute` | Operational commands that take immediate action | `ping`, `reload`, `copy` |

---

### Useful `get` Commands for System Health

```
get system status                    # Firmware version, serial number, license, uptime
get system performance status        # CPU and memory usage
get system interface physical        # Physical interface link state, speed, duplex
get system interface                 # Interface config (IP, type, status)
get router info routing-table all    # Full routing table
get system arp                       # ARP cache
get hardware nic <port-name>         # Detailed NIC info for a specific port
```

---

## Console Access Procedure

All devices have an RJ45 console port. You will need:

- A USB-to-RJ45 console cable (included with each device or provided at your workstation)
- A terminal emulator: PuTTY, SecureCRT, or equivalent
- Console settings: **9600 baud, 8 data bits, no parity, 1 stop bit, no flow control** (9600-8-N-1)

### Step 1 — Connect to the FortiGate FG-121G

1. Locate the **Console** port on the rear panel of the FG-121G (RJ45 labeled "Console").
2. Connect your console cable from your laptop USB port to the FG-121G Console port.
3. Open your terminal emulator and connect at **9600-8-N-1**.
4. Press Enter. You should see the FortiGate login prompt:

```
FG121G login:
```

5. Log in with the default credentials:
   - Username: `admin`
   - Password: *(blank — press Enter)*

> **Security Note:** The `admin` account has no password at factory default. You will set one in Module 01. Never leave a production FortiGate with no admin password.

6. After login you will see the CLI prompt:

```
FG121G #
```

### Step 2 — Connect to the FS-1024E Core Switch

1. Locate the **Console** port on the FS-1024E (RJ45, front or rear panel depending on physical orientation in your rack).
2. Connect and open terminal emulator at **9600-8-N-1**.
3. Login:
   - Username: `admin`
   - Password: *(blank)*

```
FS-1024E #
```

> **Lab Note:** After FortiLink is established in Module 05, you will be able to reach all FortiSwitch CLIs from the FortiGate GUI or by using `execute switch-controller custom-command` — no separate console cable needed for normal operations.

### Step 3 — Connect to FortiSwitch Access Layer

The FS-448E and FS-448E-FPOE use the same procedure. Console at **9600-8-N-1**.

```
S448E #     ← FS-448E prompt
S448EFP #   ← FS-448E-FPOE prompt
```

> The FS-448E and FS-448E-FPOE are **identical in software and CLI** — the only difference is the PoE capability of the FPOE model. Everything you do on one applies to the other.

---

## Pre-Lab Checklist

Work through this list before proceeding to Module 01. Check off each item as you verify it.

### Physical Verification

- [ ] FG-121G is powered on — front panel LEDs are green/amber (not red)
- [ ] FS-1024E is powered on — both PSUs show green
- [ ] FS-448E (ToR) is powered on
- [ ] FS-448E-FPOE (PoE Access) is powered on
- [ ] FAP-441K is present but **not yet connected** to PoE switch (we connect it in Module 06)
- [ ] Your laptop console cable is connected to the **FG-121G** Console (RJ45) port
- [ ] Terminal emulator is open and connected at 9600-8-N-1

### Software Verification

After logging into the FG-121G, run:

```
get system status
```

Confirm the output shows:

```
Version: FortiGate-121G v7.6.6,buildXXXX ...
Serial-Number: FG121GXXXXXXXXXX
License Status: Valid
```

- [ ] FortiOS version is **7.6.6**
- [ ] Serial number is visible (record it here: ________________)
- [ ] License status shows **Valid** with Enterprise Protection

### Clean State Verification

Check that the FortiGate has **no prior configuration** (factory default state):

```
show system interface
```

At factory default you should only see the built-in `modem`, `ssl.root`, and the physical interface stubs — no IP addresses configured except the mgmt port default of 192.168.1.99/24.

- [ ] No prior VLAN, zone, or policy configuration is present
- [ ] Admin password is blank (you can verify by logging out and back in with an empty password)

If the device has a prior configuration, proceed to the factory reset procedure below.

---

## Factory Reset Procedure

**Only perform this step if the FortiGate is NOT at factory default.** If your device is already clean, skip to the Initial Health Check section.

> **CLI Reference:** `execute factoryreset` — FortiOS 7.6.6 CLI Reference, p.3902

### FortiGate FG-121G Factory Reset

1. Connect via console (see Console Access Procedure above).
2. Log in as `admin`.
3. Type the factory reset command:

```
execute factoryreset
```

4. FortiOS will prompt for confirmation:

```
This operation will reset the system to factory default!
Do you want to continue? (y/n)
```

5. Type `y` and press Enter.
6. The FortiGate will erase its configuration and reboot. The reboot takes approximately 2–3 minutes. You will see boot messages on the console.
7. After reboot, log in again with username `admin` and a blank password.
8. Run `get system status` to confirm you are on FortiOS 7.6.6.

> **About `execute factoryreset2`:** There is a second variant — `execute factoryreset2` — which resets everything *except* VDOM mode, interface assignments, and static routes (CLI Reference p.3903). Do **not** use `factoryreset2` for this lab. Use the standard `execute factoryreset` which gives you a completely clean slate.

### FortiSwitch Factory Reset

FortiSwitch devices can be reset from their own console with:

```
execute factoryreset
```

This is the same command, identical behavior. Confirm with `y` when prompted.

> **Lab Note:** In most lab scenarios the FortiSwitches will be at factory default already. Verify by checking that the FS-1024E, FS-448E, and FS-448E-FPOE do NOT have any pre-configured VLANs or uplink assignments beyond the factory defaults.

---

## Initial Health Check

Run these commands after confirming factory default state. Record the outputs — you will use them to verify change impact in later modules.

### FortiGate Health Check Commands

```
# System version and license
get system status

# Interface physical state (link up/down, speed)
get system interface physical

# Current routing table (should be minimal at factory default)
get router info routing-table all

# CPU and memory
get system performance status
```

**Expected output at factory default:**

- `get system status` → FortiOS 7.6.6, valid Enterprise Protection license
- `get system interface physical` → mgmt port shows link-up if connected; all other ports link-down
- `get router info routing-table all` → only the mgmt connected route (192.168.1.0/24 via mgmt)
- `get system performance status` → CPU should be less than 20% at idle; memory should be less than 50% used

### Connectivity Verification

From your laptop connected to the FG-121G **mgmt** port:

1. Ensure your laptop has a static IP in the 192.168.1.x/24 range (e.g., 192.168.1.100/24, gateway 192.168.1.99).
2. Ping the FG-121G mgmt address:

```
ping 192.168.1.99
```

3. From the FortiGate CLI, ping your laptop:

```
execute ping 192.168.1.100
```

> **CLI Reference:** `execute ping <ip>` — FortiOS 7.6.6 CLI Reference, p.3948

You should see successful ping responses in both directions.

- [ ] Ping from laptop to FortiGate mgmt succeeds
- [ ] Ping from FortiGate to laptop succeeds

---

## FortiOS 7.6.6 — Key Release Notes for This Lab

The following items from the FortiOS 7.6.6 Release Notes (March 9, 2026) are relevant to this workshop:

**This is a General Availability (GA) maintenance release** in the FortiOS 7.6 branch. It is the recommended production version as of the release date and the version used throughout this workshop.

**FortiLink behavior:** FortiLink automatic authorization is enabled by default in 7.6.x. When a FortiSwitch is discovered via FortiLink, it will appear in the FortiGate GUI pending authorization — you authorize it explicitly before it is managed. This is covered in detail in Module 05.

**Enterprise Protection license:** With the Enterprise Protection bundle active on the FG-121G, all FortiGuard services are available: Antivirus, IPS, Web Filtering, Application Control, Anti-Spam, DNS Filter, Inline CASB, and Security Rating. All security profile modules in this workshop assume this license tier.

**Wi-Fi 7 and FAP-441K:** FortiOS 7.6.6 includes full Wi-Fi 7 (802.11be) support for the FAP-441K. The FAP-441K's dedicated scanning radio (R4) is visible in the wireless controller and does not serve client traffic — it is used for rogue AP detection and RF analysis. This is covered in Module 06.

---

## Lab Safety Notes

**Do not make changes out of sequence.** Each module builds on the previous. Skipping steps or pre-configuring objects from a later module will cause conflicts that are time-consuming to troubleshoot.

**Do not connect the FortiAP until Module 06.** Plugging the FAP-441K into the PoE switch before the wireless controller is configured will cause the AP to boot in standalone mode, which requires a separate reset procedure to recover.

**Reboots save configuration.** Unlike Cisco IOS, there is no concept of an unsaved config being lost on reboot. If you reboot a FortiGate, your configuration is preserved. The only way to truly start over is `execute factoryreset`.

**Console sessions do not time out by default in lab.** In production, you should configure `config system console` → `set timeout <minutes>` to prevent unattended console access. We will leave this unconfigured for lab convenience.

---

## Instructor Notes

> *This section is for the workshop facilitator. Participants can read it, but it is written for the person running the session.*

**Preparation (day before):**
- Verify all four FortiLink-capable SFP+ cables are in place between the FG-121G and FS-1024E
- Confirm both PSUs are seated and green on the FS-1024E
- Pre-stage console cable for FG-121G — participants should be able to connect immediately on arrival
- Verify Enterprise Protection license is active (`get system status` → check License Status)
- Perform a factory reset on all devices the evening before — do NOT leave any prior workshop config

**Common issues at this stage:**
- **Blank screen on console:** Baud rate is wrong. Confirm 9600-8-N-1. Some USB-to-RJ45 adapters require a driver — have macOS/Windows drivers on a USB stick
- **"admin" password rejected:** The device has a prior admin password set. Perform factory reset via the physical Reset button on the rear panel (hold 10+ seconds until LEDs flash) as a last resort
- **License shows "Invalid":** The FG-121G may not have Internet access to reach FortiGuard for license validation. Connect port1 to a DHCP-enabled upstream for validation, or apply the license manually via the GUI (System → FortiGuard)
- **FS-1024E fan noise:** The FS-1024E runs front-to-back airflow and has active cooling. The fans are loud at startup — this is normal. Noise reduces as the chassis thermals stabilize

**Cisco-to-Fortinet friction points to watch for:**
- Participants will try to type `conf t` — gently redirect to `config system global` or the specific tree they need
- Participants will forget that `end` saves — remind them there is no undo after `end`
- The `show` command in FortiOS shows only non-default values. If a participant expects to see an interface's full config but the output is short, that means many settings are at default — this is expected
- The FortiGate GUI is exceptionally powerful and intuitive. While this workshop is CLI-focused (because Cisco engineers are comfortable there), encourage participants to open the GUI in parallel at `https://192.168.1.99` — seeing both views simultaneously accelerates learning

**Timing guidance:**
- Allow 30–45 minutes for this pre-lab module including group discussion
- The CLI orientation section generates the most questions — plan for it
- If participants are already familiar with Fortinet, the lab checklist and factory reset can be completed in under 15 minutes

---

## Module 00 Complete

When your checklist is fully checked off and the FortiGate health check commands show expected output, you are ready to proceed.

**Next:** [Module 01 — FortiGate Initial Setup](Module-01-FortiGate-Initial-Setup.md)

---

*All CLI commands in this document are verified against the FortiOS 7.6.6 CLI Reference (Fortinet Inc., 2026-01-28). Page references are to the CLI Reference PDF.*

| Command | CLI Reference Page |
|---|---|
| `execute factoryreset` | p.3902 |
| `execute factoryreset2` | p.3903 |
| `execute reboot` | p.3957 |
| `execute ping <ip>` | p.3948 |
| `execute cfg save` | p.3883–3884 |
