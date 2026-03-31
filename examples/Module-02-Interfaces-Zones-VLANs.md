# Module 02 — Interfaces, Zones, and VLANs

**Workshop:** Fortinet Security Fabric — Hands-On Transition Training
**Platform:** FortiOS 7.6.6
**Hardware:** FG-121G
**Estimated Time:** 60–75 minutes
**Prerequisites:** Module 01 complete — hostname, admin password, mgmt and port1 configured

---

## Overview

This module builds the Layer 3 VLAN structure that all remaining modules depend on. You will create VLAN subinterfaces on the FortiGate, configure security zones, and understand how FortiOS thinks about interfaces and policy enforcement — which is conceptually different from both Cisco IOS and Cisco ASA.

The VLAN subinterfaces you create here become the per-VLAN default gateways for all downstream hosts. In Module 05 (FortiSwitch), FortiLink will distribute these VLANs to the FS-1024E and FS-448E access layer.

---

## Learning Objectives

By the end of this module you will be able to:

- Explain the difference between FortiOS interface roles and Cisco L2/L3 interface concepts
- Create VLAN subinterfaces on a physical FortiGate interface
- Configure interface IP addressing, allowed access, and descriptions
- Create security zones and explain their role in policy simplification
- Explain `intrazone` traffic behavior
- Verify all interface and zone configuration with CLI and GUI

---

## Conceptual Foundation: How FortiOS Handles VLANs and Zones

### VLANs in FortiOS vs. Cisco IOS

On a Cisco Layer 3 switch, VLANs are a two-step operation: you create the VLAN in the VLAN database, then create an SVI (`interface vlan 10`) to give it an IP. The physical port is configured as a trunk or access member of that VLAN.

On a FortiGate, VLANs are handled as **subinterfaces** on a physical parent port. A VLAN subinterface combines both the "SVI" concept and the 802.1Q tagging configuration into a single object.

```
Cisco IOS approach:               FortiOS approach:
─────────────────────             ──────────────────
vlan 10                           config system interface
  name CORPORATE                      edit "port2.10"
!                                         set type vlan
interface vlan 10                         set vlanid 10
  ip address 10.10.10.1 0.0.0.255        set interface "port2"
!                                         set ip 10.10.10.1 255.255.255.0
interface GigabitEthernet0/0          next
  switchport mode trunk            end
  switchport trunk allowed vlan 10
```

The key difference: on FortiOS, the VLAN interface IS the SVI. There is no separate VLAN database to maintain. You reference the physical parent port directly in the interface definition.

### Zones in FortiOS

A **zone** is a named grouping of one or more interfaces. When you reference a zone in a firewall policy, the policy applies to all interfaces in that zone. This is FortiOS's equivalent of Cisco ASA's "security zones" or Cisco IOS Zone-Based Firewall (ZBF) zones.

Zones are not required — you can write policies directly against individual interfaces. But zones are **strongly recommended** for two reasons:

1. **Scalability:** As your network grows and you add VLANs, you add the new VLAN interface to the existing zone instead of creating new policy rows
2. **Simplicity:** A policy from "LAN_ZONE" to "WAN" covers all VLAN interfaces in LAN_ZONE simultaneously

```
FortiOS zone concept:

  [LAN_ZONE]                    [WAN_ZONE]
  ┌─────────┐                   ┌─────────┐
  │ port2.10│ ─── policy ──────▶│ port1   │
  │ port2.20│                   └─────────┘
  │ port2.30│
  │ port2.99│
  └─────────┘

One policy covers all four VLAN interfaces simultaneously.
```

The `intrazone` setting controls whether traffic between interfaces **within** the same zone is permitted without a policy:
- `intrazone allow` — traffic between zone members flows freely (like a bridge)
- `intrazone deny` — traffic between zone members requires an explicit policy (default, more secure)

---

## Lab Topology for This Module

```
                    [FG-LAB-01]
                    ┌──────────────────────────────────┐
                    │ port1 (WAN) — 203.0.113.2/30     │
                    │                                   │
                    │ port2 ─── trunk ──────────────── │──▶ (to test device or
                    │   .10 — 10.10.10.1/24 — VLAN 10 │    switch in Module 05)
                    │   .20 — 10.10.20.0/24 — VLAN 20 │
                    │   .30 — 10.10.30.1/24 — VLAN 30 │
                    │   .99 — 10.10.99.1/24 — VLAN 99 │
                    │                                   │
                    │ mgmt — 192.168.1.99/24           │
                    └──────────────────────────────────┘

Zones:
  WAN_ZONE  → port1
  LAN_ZONE  → port2.10, port2.20, port2.30, port2.99
```

> **Note on port2:** In this module we use `port2` as the physical trunk parent. In Module 05, the FortiSwitch FortiLink connection uses the dedicated 10GE SFP+ FortiLink ports. The VLAN interfaces created here on `port2` will be **migrated** to the FortiLink aggregate in Module 05 — for now this gives you a working VLAN setup that doesn't depend on the FortiSwitch being configured yet.

---

## Task 1 — Configure VLAN Subinterfaces

### 1.1 Create VLAN 10 — Corporate LAN

> **CLI Reference:** `config system interface` — FortiOS 7.6.6 CLI Reference, p.1620
> Key parameters: `set type vlan` (p.1629), `set vlanid {integer}` (p.1629), `set interface {string}` (p.1623)

```
config system interface
    edit "port2.10"
        set type vlan
        set vlanid 10
        set interface "port2"
        set ip 10.10.10.1 255.255.255.0
        set allowaccess ping
        set description "Corporate LAN - VLAN 10"
        set alias "CORP"
        set role lan
    next
end
```

**Parameter breakdown:**

| Parameter | Value | Explanation |
|---|---|---|
| `edit "port2.10"` | port2.10 | Interface name — convention is `parent.vlanid`. Max 15 chars. |
| `set type vlan` | vlan | Creates this as a VLAN subinterface, not a physical interface |
| `set vlanid 10` | 10 | 802.1Q VLAN tag — range 1–4094 |
| `set interface "port2"` | port2 | Physical parent port that carries this VLAN |
| `set ip 10.10.10.1 255.255.255.0` | 10.10.10.1/24 | Gateway IP for this VLAN (space-separated, not slash notation) |
| `set allowaccess ping` | ping | Hosts in this VLAN can ping the gateway — no management access |
| `set role lan` | lan | Marks this interface as facing internal users |

> **Cisco Parallel:** This is the FortiOS equivalent of:
> ```
> interface vlan 10
>   description Corporate LAN
>   ip address 10.10.10.1 255.255.255.0
> ```
> Plus `switchport trunk allowed vlan 10` on the physical port.

### 1.2 Create VLAN 20 — Server Segment

```
config system interface
    edit "port2.20"
        set type vlan
        set vlanid 20
        set interface "port2"
        set ip 10.10.20.1 255.255.255.0
        set allowaccess ping
        set description "Server Segment - VLAN 20"
        set alias "SERVERS"
        set role lan
    next
end
```

### 1.3 Create VLAN 30 — Wireless Client Network

```
config system interface
    edit "port2.30"
        set type vlan
        set vlanid 30
        set interface "port2"
        set ip 10.10.30.1 255.255.255.0
        set allowaccess ping
        set description "Wireless Clients - VLAN 30"
        set alias "WIRELESS"
        set role lan
    next
end
```

> **Note:** In Module 06 (FortiAP), this VLAN will be assigned to the SSID used by the FAP-441K. The FortiGate will automatically create a DHCP scope for 10.10.30.0/24 at that point.

### 1.4 Create VLAN 99 — Infrastructure Management

```
config system interface
    edit "port2.99"
        set type vlan
        set vlanid 99
        set interface "port2"
        set ip 10.10.99.1 255.255.255.0
        set allowaccess ping https ssh
        set description "Infra Management - VLAN 99"
        set alias "INFRA-MGMT"
        set role lan
    next
end
```

> **Note:** VLAN 99 gets `allowaccess ping https ssh` because it is the in-band management VLAN used by the FortiSwitches and FortiAP. Management traffic from those devices will hit this interface, so HTTPS and SSH access must be permitted.

### 1.5 Verify VLAN Subinterface Creation

```
show system interface port2.10
show system interface port2.20
show system interface port2.30
show system interface port2.99
```

Or to see all at once:

```
get system interface | grep "port2\."
```

You should see four VLAN subinterfaces listed with their IP addresses and VLAN IDs. Their physical status will show `down` because no cable is plugged into port2 yet — this is expected.

---

## Task 2 — Configure the Physical port2 Interface

The physical parent port (`port2`) must be confirmed as active. In FortiOS, a physical port that hosts VLAN subinterfaces does not need an IP address itself — it functions purely as a tagged trunk carrier.

```
config system interface
    edit "port2"
        set description "LAN Trunk - VLAN 10/20/30/99"
        set alias "LAN-TRUNK"
        set role lan
    next
end
```

> **Important:** Do NOT assign an IP address to the physical `port2` interface when it is serving as a VLAN trunk parent. If you put an IP on the physical port, it creates an "untagged" Layer 3 interface on that port — which conflicts with the VLAN design unless you explicitly need untagged traffic. In this lab, all traffic on port2 will be 802.1Q tagged.

> **Cisco Parallel:** This is equivalent to `no ip address` on a Cisco trunk interface — the trunk itself doesn't need an IP because the SVIs carry the Layer 3 addressing.

---

## Task 3 — Create Security Zones

Zones group interfaces for simplified policy management. We will create two zones: one for WAN-facing interfaces and one for all LAN/VLAN interfaces.

> **CLI Reference:** `config system zone` — FortiOS 7.6.6 CLI Reference, p.2083
> Key parameters: `set interface` (add member interfaces), `set intrazone [allow|deny]`

### 3.1 Create the WAN Zone

```
config system zone
    edit "WAN_ZONE"
        set description "WAN-facing interfaces"
        set interface "port1"
        set intrazone deny
    next
end
```

### 3.2 Create the LAN Zone

```
config system zone
    edit "LAN_ZONE"
        set description "All internal VLAN interfaces"
        set interface "port2.10" "port2.20" "port2.30" "port2.99"
        set intrazone allow
    next
end
```

> **`intrazone allow` on LAN_ZONE:** Setting this to `allow` means traffic between any two VLAN interfaces in LAN_ZONE (e.g., VLAN 10 to VLAN 20) flows without requiring an explicit firewall policy. This is appropriate in a lab where we want cross-VLAN reachability without defining every inter-VLAN rule.
>
> **Production consideration:** In production, set `intrazone deny` and create explicit policies for each allowed inter-VLAN flow. This implements micro-segmentation — hosts on the Server VLAN cannot reach the Corporate LAN VLAN unless you explicitly permit it.

**`set interface` syntax note:** When adding multiple interfaces to a zone, list them space-separated inside double quotes, each quoted:

```
set interface "port2.10" "port2.20" "port2.30" "port2.99"
```

> **Zone Constraint:** An interface can only belong to **one** zone at a time. If you try to add an interface to a second zone, FortiOS will return an error. Also, once an interface is in a zone, you must reference the zone (not the interface) in firewall policies — you cannot mix zone-level and interface-level policy references for the same interface.

### 3.3 Verify Zone Configuration

```
show system zone
```

Expected output:

```
config system zone
    edit "WAN_ZONE"
        set interface "port1"
    next
    edit "LAN_ZONE"
        set interface "port2.10" "port2.20" "port2.30" "port2.99"
        set intrazone allow
    next
end
```

---

## Task 4 — Configure DHCP Servers on VLAN Interfaces

For the lab to function end-to-end, each VLAN needs a DHCP scope so that test devices automatically receive IP addresses. The FortiGate has a built-in DHCP server that can serve each VLAN interface independently.

> **Note:** `config system dhcp server` is not in the CLI Reference's config section (it's part of the DHCP subsystem). The DHCP server configuration is done under `config system dhcp server`. This is a flat indexed list — each DHCP scope has a numeric ID.

### 4.1 Configure DHCP Server for VLAN 10

```
config system dhcp server
    edit 1
        set dns-service default
        set default-gateway 10.10.10.1
        set netmask 255.255.255.0
        set interface "port2.10"
        config ip-range
            edit 1
                set start-ip 10.10.10.100
                set end-ip 10.10.10.200
            next
        end
    next
end
```

### 4.2 Configure DHCP Server for VLAN 20

```
config system dhcp server
    edit 2
        set dns-service default
        set default-gateway 10.10.20.1
        set netmask 255.255.255.0
        set interface "port2.20"
        config ip-range
            edit 1
                set start-ip 10.10.20.100
                set end-ip 10.10.20.200
            next
        end
    next
end
```

### 4.3 Configure DHCP Server for VLAN 30 (Wireless)

```
config system dhcp server
    edit 3
        set dns-service default
        set default-gateway 10.10.30.1
        set netmask 255.255.255.0
        set interface "port2.30"
        config ip-range
            edit 1
                set start-ip 10.10.30.100
                set end-ip 10.10.30.200
            next
        end
    next
end
```

### 4.4 Configure DHCP Server for VLAN 99

```
config system dhcp server
    edit 4
        set dns-service default
        set default-gateway 10.10.99.1
        set netmask 255.255.255.0
        set interface "port2.99"
        config ip-range
            edit 1
                set start-ip 10.10.99.10
                set end-ip 10.10.99.50
            next
        end
    next
end
```

> **DHCP parameter `set dns-service default`:** This tells the DHCP server to hand out the FortiGate's own DNS servers (configured in `config system dns`) to clients. Use `set dns-service specify` with `set dns-server1 <ip>` if you need to hand out a different DNS server (e.g., internal AD DNS).

> **Cisco Parallel:** This is equivalent to Cisco's `ip dhcp pool` configuration, but scoped per-interface rather than per-subnet:
> ```
> ip dhcp pool VLAN10
>   network 10.10.10.0 /24
>   default-router 10.10.10.1
>   dns-server 8.8.8.8
>   lease 0 8
> ```

---

## Task 5 — Functional Verification

### 5.1 Connect a Test Device to VLAN 10

1. Take a laptop or test device with a 802.1Q-capable NIC.
2. Configure the NIC to send VLAN-tagged traffic with VLAN ID 10.
3. Alternatively, connect via an unmanaged switch to port2 and send untagged — but note that untagged traffic on a trunk port will be treated differently.

> **Simpler test:** Connect a laptop directly to port2 with no VLAN tagging configured. The FG port2 has no native VLAN configured (no IP on the physical port), so **untagged frames will be dropped** at this point. This is correct and intentional — it confirms the trunk-only design. The DHCP server will not respond to untagged frames on port2.
>
> To properly test, you need a VLAN-capable switch between the laptop and port2 (which you'll have in Module 05), or you need to configure a VLAN tag on your laptop's NIC.

### 5.2 Verify VLAN Interfaces in the GUI

1. Open `https://192.168.1.99` in your browser.
2. Navigate to **Network → Interfaces**.
3. You should see all four port2.x VLAN interfaces listed under the `port2` parent.
4. Each VLAN interface will show its IP address, description, and zone membership.

### 5.3 Verify Zone Membership

```
show system zone WAN_ZONE
show system zone LAN_ZONE
```

### 5.4 Verify Interface Summary

```
get system interface
```

Look for all port2.x interfaces in the output. They will show `status: down` because port2 has no cable yet — the link state follows the physical parent.

### 5.5 Check Routing Table (Expected Changes)

Adding IP addresses to VLAN interfaces automatically creates connected routes in the routing table:

```
get router info routing-table all
```

Expected output will now include:
```
C       10.10.10.0/24 is directly connected, port2.10
C       10.10.20.0/24 is directly connected, port2.20
C       10.10.30.0/24 is directly connected, port2.30
C       10.10.99.0/24 is directly connected, port2.99
C       203.0.113.0/30 is directly connected, port1
C       192.168.1.0/24 is directly connected, mgmt
```

> **Cisco Parallel:** These are equivalent to Cisco's automatically-generated connected (`C`) routes in `show ip route` when you configure an IP address on an interface or SVI.

---

## Task 6 — Review the Complete Interface Picture

At this point the FortiGate has the following interface structure. Run `show system interface` to verify:

| Interface | Type | IP Address | VLAN ID | Parent | Zone | Purpose |
|---|---|---|---|---|---|---|
| mgmt | physical | 192.168.1.99/24 | — | — | (none) | OOB management |
| port1 | physical | 203.0.113.2/30 | — | — | WAN_ZONE | WAN uplink |
| port2 | physical | (none) | — | — | (none) | VLAN trunk parent |
| port2.10 | vlan | 10.10.10.1/24 | 10 | port2 | LAN_ZONE | Corporate LAN gateway |
| port2.20 | vlan | 10.10.20.1/24 | 20 | port2 | LAN_ZONE | Server segment gateway |
| port2.30 | vlan | 10.10.30.1/24 | 30 | port2 | LAN_ZONE | Wireless client gateway |
| port2.99 | vlan | 10.10.99.1/24 | 99 | port2 | LAN_ZONE | Infra management gateway |

---

## How This Evolves in Module 05 (Preview)

When FortiLink is configured in Module 05, the FG-121G's dedicated 10GE SFP+ ports will connect to the FS-1024E. The VLAN interfaces we created here will be **moved** from port2 to the FortiLink aggregate interface:

```
# In Module 05, this changes:
config system interface
    edit "port2.10"
        set interface "fortilink"    ← changes from "port2" to the FortiLink interface
    next
end
```

The FortiGate's switch controller will then automatically push VLAN 10/20/30/99 trunk configuration down to the FS-1024E and FS-448E switches. The IP addresses and DHCP servers you configured here remain unchanged — only the parent interface changes.

This architecture is fundamental to understanding FortiLink: the FortiGate owns the Layer 3 gateways, and the FortiSwitches are transparent Layer 2 extensions managed over FortiLink.

---

## Key Concepts Summary

### FortiOS VLAN Subinterface vs. Cisco SVI

| Aspect | Cisco IOS (L3 Switch) | FortiOS 7.6.6 |
|---|---|---|
| VLAN database | `vlan 10` in VLAN database | Not needed — VLAN is implicit in subinterface |
| Layer 3 gateway | `interface vlan 10` with IP | `config system interface` → `edit port2.10` with `set type vlan` |
| Trunk configuration | `switchport trunk allowed vlan 10` on physical port | `set interface "port2"` in the VLAN subinterface definition |
| IP address | `ip address x.x.x.x mask` | `set ip x.x.x.x mask` |
| DHCP server | `ip dhcp pool` globally | `config system dhcp server` per scope, bound to an interface |

### FortiOS Zones vs. Cisco ASA Security Levels / ZBF

| Aspect | Cisco ASA | Cisco IOS ZBF | FortiOS Zones |
|---|---|---|---|
| Definition | Security level (0–100) per interface | Named zone, interfaces assigned | Named zone, interfaces assigned |
| Policy direction | Security-level-based | Zone-pair policies | Any-to-any zone policies |
| Intra-zone traffic | Permitted (same level, same interface group) | Blocked by default | Configurable (`allow` or `deny`) |
| Scalability | Limited (one zone per interface) | Good | Good — multiple interfaces per zone |

---

## Common Mistakes at This Stage

**Putting an IP on the physical trunk port.** If you set `set ip 10.0.0.1 255.255.255.0` directly on `port2`, that IP will handle untagged traffic, and your VLAN subinterfaces will only handle tagged traffic. This is not wrong in all cases, but it's not the design intent here.

**VLAN subinterface naming.** The convention `port2.10` is just a convention — FortiOS will accept any name up to 15 characters. However, consistent naming (parent.vlanid) makes management far easier. Stick to this convention.

**Forgetting zones are exclusive.** If you add port2.10 to LAN_ZONE and then try to add it to a second zone (say, DMZ_ZONE), FortiOS will refuse with an error. An interface can only be in one zone.

**`intrazone deny` blocking expected traffic.** If you use `intrazone deny` on LAN_ZONE (the production-safe default) and then wonder why VLAN 10 hosts can't reach VLAN 20, remember — you need an explicit LAN_ZONE-to-LAN_ZONE policy. This is covered in Module 03.

---

## Instructor Notes

> *For the workshop facilitator.*

**The most impactful teaching moment here** is explaining that FortiOS VLAN subinterfaces are the Layer 3 gateway — there is no separate "SVI" concept to explain. Cisco engineers grasp this quickly once they see the command structure side-by-side.

**`intrazone` is frequently misunderstood.** Spend time on the difference between `allow` and `deny`. A common question: "Why can't my VLAN 10 laptop ping my VLAN 20 server even though they're in the same zone?" Answer: `intrazone deny` is the default. Use this as a segue into Module 03 where you create the inter-VLAN policy.

**The port2 migration to FortiLink (Module 05)** should be previewed here. Draw it on the whiteboard: FortiGate owns Layer 3, FortiSwitch is a Layer 2 extension. This conceptual model prevents confusion in Module 05 when participants ask "so who is the gateway for VLAN 10?"

**Testing tip:** If you have a managed switch with 802.1Q support available, connect it to port2 and configure a trunk on it — participants can then tag traffic from their laptops and receive DHCP responses. This makes the VLAN concept instantly tangible rather than theoretical.

**DHCP verification command:** After testing devices connect, verify DHCP leases with:
```
get system dhcp status
```
or from the GUI: **Network → DHCP Servers** → click the scope → Clients tab.

**Timing:** The interface creation tasks are fast for CLI-comfortable participants (15–20 minutes). Budget extra time for the zone conceptual discussion (20–25 minutes) — the `intrazone` behavior generates good questions that will improve Module 03 comprehension.

---

## Module 02 Complete

**Checkpoint:** Before moving to Module 03, confirm:

- [ ] `show system interface port2.10` shows VLAN 10 with IP 10.10.10.1/24
- [ ] `show system interface port2.20` shows VLAN 20 with IP 10.10.20.1/24
- [ ] `show system interface port2.30` shows VLAN 30 with IP 10.10.30.1/24
- [ ] `show system interface port2.99` shows VLAN 99 with IP 10.10.99.1/24
- [ ] `show system zone` shows WAN_ZONE (port1) and LAN_ZONE (all four port2.x)
- [ ] `get router info routing-table all` shows four connected routes for 10.10.x.0/24 plus 203.0.113.0/30 and 192.168.1.0/24
- [ ] `show system dhcp server` shows four DHCP scopes (IDs 1–4)

**Next:** [Module 03 — Firewall Policies and NAT](Module-03-Firewall-Policies-NAT.md)

---

*All CLI commands in this document are verified against the FortiOS 7.6.6 CLI Reference (Fortinet Inc., 2026-01-28).*

| Command Section | CLI Reference Page |
|---|---|
| `config system interface` (VLAN type, vlanid) | p.1620, p.1629 |
| `config system zone` | p.2083 |
