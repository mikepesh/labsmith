# Module 01 — FortiGate Initial Setup

**Workshop:** Fortinet Security Fabric — Hands-On Transition Training
**Platform:** FortiOS 7.6.6
**Hardware:** FG-121G
**Estimated Time:** 45–60 minutes
**Prerequisites:** Module 00 complete — FortiGate at factory default, console session active

---

## Overview

In this module you configure the FortiGate FG-121G from its factory-default blank state to a fully functional, network-ready baseline. Every production FortiGate deployment starts here regardless of what comes after — the same commands, the same order.

By the end of this module the FortiGate will have a hostname, admin password, management interface IP, WAN interface IP, DNS, and NTP configured. You will also access the GUI for the first time.

---

## Learning Objectives

By the end of this module you will be able to:

- Configure FortiGate global system parameters (hostname, timezone, admin timeout)
- Set a secure admin password and understand FortiOS admin account structure
- Configure physical interface IP addresses and management access methods
- Configure DNS and NTP on FortiOS
- Access the FortiGate GUI and understand its layout
- Verify all baseline configuration with `get` and `show` commands

---

## Lab Topology for This Module

```
[Instructor Laptop]
  192.168.1.100/24
       │
       │ Ethernet (direct or via switch)
       │
[FG-121G — mgmt port]
  192.168.1.99/24 ← default; we will verify and keep this
       │
[FG-121G — port1]       ← WAN (not yet connected to upstream)
  203.0.113.2/30         (we configure this now; cable in Module 02)
```

---

## Task 1 — Configure Global System Parameters

### 1.1 Set Hostname, Timezone, and Admin Timeout

The `config system global` section controls system-wide behavior. Think of this as equivalent to Cisco's `hostname`, `clock timezone`, and `exec-timeout` commands — but all in one place.

> **CLI Reference:** `config system global` — FortiOS 7.6.6 CLI Reference, p.1532

**Step 1:** From the FortiGate CLI console, enter the global configuration tree:

```
config system global
    set hostname FG-LAB-01
    set timezone 12
    set admintimeout 60
    set admin-concurrent enable
    set language english
end
```

**Command explanations:**

| Command | What it does | Cisco equivalent |
|---|---|---|
| `set hostname FG-LAB-01` | Sets the device hostname | `hostname FG-LAB-01` |
| `set timezone 12` | Sets system timezone (integer code — see note below) | `clock timezone EST -5` |
| `set admintimeout 60` | Admin GUI/CLI idle timeout in minutes (0 = disable) | `exec-timeout 60 0` |
| `set admin-concurrent enable` | Allow multiple admins simultaneously | N/A (IOS allows by default) |
| `set language english` | GUI display language | N/A |

> **Timezone Note:** FortiOS uses an integer code for timezone. Run `set timezone ?` inside `config system global` to see the full list. Common values: `4` = US/Central, `12` = US/Eastern. Your instructor will confirm the correct value for this facility's location.

**Step 2:** Verify the change took effect. Notice your prompt now shows the new hostname:

```
FG-LAB-01 #
```

Confirm settings:

```
show system global
```

You should see `set hostname FG-LAB-01` in the output. Notice that FortiOS `show` only displays values that differ from defaults — this is intentional and different from Cisco `show running-config` which shows everything.

> **Cisco Tip:** If a parameter you set doesn't appear in `show` output, it means you set it to its default value. Use `show full-configuration system global` to force display of all parameters including defaults.

---

### 1.2 Review What You Just Did

Notice there was no `write memory` at the end. FortiOS saved your changes automatically when you typed `end`. This is one of the most important behavioral differences from Cisco IOS — **every `end` commits and persists immediately.**

If you mistype something inside a config block and want to abandon your changes:
- **Before typing `end`:** Type `abort` — this exits the config tree without saving the changes you made in this session
- **After typing `end`:** You must re-enter the config tree and manually revert the value

---

## Task 2 — Configure the Admin Account

### 2.1 Set the Admin Password

The default `admin` account has no password at factory default. This is the first thing you must fix.

> **CLI Reference:** `config system admin` — FortiOS 7.6.6 CLI Reference, p.1400

```
config system admin
    edit admin
        set password Fortinet@2024!
    next
end
```

> **Important:** After typing `end`, you will be prompted to confirm the new password. Future console and GUI logins will require this password. Do NOT lose it — a forgotten admin password on a FortiGate requires a physical console break procedure to recover.

**Step:** Log out and log back in to verify:

```
FG-LAB-01 # exit

FG-LAB-01 login: admin
Password: <enter your new password>
FG-LAB-01 #
```

### 2.2 Understanding FortiOS Admin Account Structure

FortiOS admin accounts are more granular than Cisco `privilege levels`. Each admin account has:

- **An access profile** (`set accprofile`) — defines which features the account can read/write
- **Trust hosts** (`set trusthost1` through `trusthost10`) — IP addresses/subnets from which this admin can log in
- **Two-factor authentication** options (`set two-factor`)

The default `admin` account uses the built-in `super_admin` profile which has read/write access to everything. For production, best practice is to create additional limited-access accounts for different roles and restrict trust hosts to management subnets.

For this lab we use the single `admin` account with no trust host restriction (which means access from any IP is permitted).

### 2.3 Create a Read-Only Admin Account (Optional — Instructor Demo)

This demonstrates how role-based admin accounts work:

```
config system admin
    edit labviewer
        set accprofile prof_admin
        set password ViewOnly@2024!
        set comments "Read-only lab observer account"
    next
end
```

> **Note:** `prof_admin` is a built-in read-only profile. Full custom profiles can be created under `config accprofile`. This is beyond this module's scope but demonstrates the capability.

---

## Task 3 — Configure the Management Interface

The `mgmt` port is the dedicated out-of-band management interface on the FG-121G. It is separate from the data-plane ports (port1–port16, FortiLink ports, etc.) and does not participate in firewall policy matching.

> **CLI Reference:** `config system interface` — FortiOS 7.6.6 CLI Reference, p.1620

### 3.1 Verify the Current mgmt Interface Configuration

```
show system interface mgmt
```

At factory default you should see:

```
config system interface
    edit "mgmt"
        set vdom "root"
        set ip 192.168.1.99 255.255.255.0
        set allowaccess ping https ssh http
        set type physical
        set role lan
    next
end
```

The factory default for the `mgmt` port is `192.168.1.99/24` with HTTPS, SSH, ping, and HTTP allowed. This is the IP you connected to in Module 00.

### 3.2 Update the mgmt Interface

We will keep the factory default IP but update the allowed access methods and add a description:

```
config system interface
    edit mgmt
        set ip 192.168.1.99 255.255.255.0
        set allowaccess ping https ssh
        set description "OOB Management - Lab"
        set alias "MGMT"
    next
end
```

**What we changed:**
- Removed `http` from `allowaccess` — HTTP is unencrypted; HTTPS is preferred
- Added a description (visible in GUI and `show` output)

> **Cisco Parallel:** `set allowaccess` is analogous to Cisco's `ip http secure-server`, `transport input ssh`, etc. — but combined into a single attribute that lists all allowed management protocols for that interface.

**Allowaccess options:**

| Value | Protocol | Port | Notes |
|---|---|---|---|
| `ping` | ICMP echo | — | Allow ping to this interface |
| `https` | HTTPS | TCP/443 | GUI and REST API access |
| `ssh` | SSH | TCP/22 | CLI access |
| `http` | HTTP | TCP/80 | Unencrypted GUI (not recommended) |
| `snmp` | SNMP | UDP/161 | SNMP polling |
| `telnet` | Telnet | TCP/23 | Unencrypted CLI (not recommended) |
| `fgfm` | FortiManager | TCP/541 | FortiManager management protocol |
| `fabric` | Security Fabric | TCP/8013 | Fabric connectivity |
| `capwap` | CAPWAP | UDP/5246,5247 | FortiAP management |

---

## Task 4 — Configure the WAN Interface (port1)

Port1 is the primary WAN-facing interface on the FG-121G. In this lab, it connects to a simulated upstream router.

> **Note:** The physical cable from port1 to the upstream router is connected by the instructor. For this task you are configuring the logical settings — the cable connection completes the circuit in Module 02 when we verify reachability end-to-end.

### 4.1 Configure port1 as a Static WAN Interface

```
config system interface
    edit port1
        set ip 203.0.113.2 255.255.255.252
        set allowaccess ping
        set description "WAN - Upstream ISP/Router"
        set alias "WAN"
        set role wan
    next
end
```

**Key points:**
- `203.0.113.0/30` is from the IANA documentation range (RFC 5737) — appropriate for lab WAN simulation
- `allowaccess ping` on WAN allows ICMP only — no management access from the WAN side (security best practice)
- `set role wan` — tells FortiOS this interface faces the internet (affects SD-WAN, SLA, and some default behaviors)

> **Cisco Parallel:** This is like `ip address 203.0.113.2 255.255.255.252` on a Cisco interface, plus specifying `no ip proxy-arp` and restricting access lists — all bundled together.

### 4.2 Verify Interface Configuration

```
show system interface port1
show system interface mgmt
```

Or view all interfaces at once:

```
get system interface
```

The `get system interface` command shows the operational state including link status, IP, and allowaccess for every interface. Look for:
- `mgmt` → IP 192.168.1.99/24, status: up
- `port1` → IP 203.0.113.2/30, status: down (expected — cable will be connected later)
- All other ports → no IP, down (expected at this stage)

---

## Task 5 — Configure DNS

The FortiGate needs DNS to resolve FortiGuard server names for license validation, threat intelligence updates, and web filtering category lookups.

> **CLI Reference:** `config system dns` — FortiOS 7.6.6 CLI Reference, p.1482

### 5.1 Configure DNS Servers

```
config system dns
    set primary 8.8.8.8
    set secondary 8.8.4.4
    set domain lab.local
end
```

**Parameter explanations:**

| Parameter | Value | Description |
|---|---|---|
| `set primary` | 8.8.8.8 | Primary DNS server (Google Public DNS) |
| `set secondary` | 8.8.4.4 | Secondary DNS server |
| `set domain` | lab.local | DNS search domain (appended to unqualified hostnames) |

> **Production Note:** In a production environment, point DNS to your internal resolvers or to your ISP's DNS. Using public DNS (8.8.8.8) for FortiGuard lookups is acceptable and Fortinet-supported. For private domain resolution, configure your internal DNS server as `primary` and use `secondary` as a public fallback.

> **Cisco Parallel:** Equivalent to `ip name-server 8.8.8.8 8.8.4.4` and `ip domain-name lab.local`.

### 5.2 Verify DNS

```
show system dns
```

Expected output:
```
config system dns
    set primary 8.8.8.8
    set secondary 8.8.4.4
    set domain "lab.local"
end
```

Test DNS resolution from the CLI (requires WAN connectivity — will work after Module 02 cabling):

```
execute ping update.fortiguard.net
```

If DNS is working, you will see the resolved IP in the ping output. If WAN is not yet up, you will see `ping: sendto: Network is unreachable` — this is expected at this stage.

---

## Task 6 — Configure NTP

Accurate system time is critical on a security device. Log timestamps, certificate validity checks, and VPN authentication all depend on synchronized clocks.

> **CLI Reference:** `config system ntp` — FortiOS 7.6.6 CLI Reference, p.1874

### 6.1 Enable NTP Synchronization

FortiOS defaults to using Fortinet's FortiGuard NTP service (`set type fortiguard`). For lab environments where FortiGuard access may not be available yet, we configure a public NTP pool as a fallback:

```
config system ntp
    set ntpsync enable
    set type custom
    config ntpserver
        edit 1
            set server 0.pool.ntp.org
        next
        edit 2
            set server 1.pool.ntp.org
        next
    end
    set syncinterval 60
end
```

**Parameter explanations:**

| Parameter | Value | Description |
|---|---|---|
| `set ntpsync enable` | enable | Activates NTP synchronization (default: disable) |
| `set type custom` | custom | Use specified NTP servers, not FortiGuard NTP |
| `set server` | pool.ntp.org | NTP server FQDN |
| `set syncinterval` | 60 | Sync every 60 minutes (default: 60, range: 1–1440) |

> **Production Note:** For production deployments where FortiGuard connectivity is confirmed, use `set type fortiguard` — Fortinet's NTP service is pre-authorized through FortiGuard communication channels and requires no additional firewall rules.

> **Cisco Parallel:** Equivalent to `ntp server 0.pool.ntp.org` and `ntp server 1.pool.ntp.org`.

### 6.2 Verify NTP

```
show system ntp
```

Check system time:

```
get system status
```

Look for the `System time:` line in the output. After NTP sync (which requires WAN connectivity), the time will be accurate. For now, verify the configuration is correct.

---

## Task 7 — Access the FortiGate GUI

The FortiGate GUI is a full-featured web interface that provides visual representations of everything you can configure via CLI. While this workshop is CLI-focused, becoming comfortable with the GUI accelerates operations work.

### 7.1 Connect to the GUI

1. Open a browser on your laptop.
2. Navigate to: `https://192.168.1.99`
3. Accept the self-signed certificate warning (expected on a new device).
4. Log in with `admin` and the password you set in Task 2.

> **Browser Tip:** Chrome and Firefox may show a stern warning about the self-signed certificate. Click "Advanced" → "Proceed to 192.168.1.99 (unsafe)" or the equivalent in your browser. The self-signed certificate will be replaced with a CA-signed certificate in production.

### 7.2 GUI Layout Overview

| GUI Area | Location | What It Contains |
|---|---|---|
| Dashboard | Home screen | Widget-based system overview — CPU, memory, sessions, licenses |
| Network | Left nav | Interfaces, SD-WAN, DNS, routing |
| Policy & Objects | Left nav | Firewall policies, NAT, addresses, services, schedules |
| Security Profiles | Left nav | AV, IPS, Web Filter, Application Control, etc. |
| VPN | Left nav | IPsec and SSL VPN configuration |
| WiFi & Switch Controller | Left nav | FortiAP and FortiSwitch management |
| System | Left nav | Administrators, certificates, HA, SNMP |
| Log & Report | Left nav | Log viewer, traffic analysis, reports |
| CLI Console | Top-right icon | Embedded browser-based CLI (useful for side-by-side GUI/CLI work) |

### 7.3 GUI vs. CLI

Everything in this workshop is doable from either the GUI or CLI. Here is when to use each:

**Use the CLI when:**
- Automating or scripting configuration
- Applying configuration from a text file or template
- Troubleshooting with diagnostic commands (`diagnose` tree)
- Working with deeply nested configuration objects
- In a session with poor browser connectivity

**Use the GUI when:**
- Getting a visual topology view of Security Fabric devices
- Building firewall policies (drag-and-drop policy ordering)
- Reviewing log traffic with filtering
- Managing FortiSwitch and FortiAP (the visual views are exceptionally useful)
- Reviewing license and subscription status

---

## Task 8 — Verification and Summary

### 8.1 Full Baseline Verification

Run these commands and verify each output matches the expected state:

**System identity:**
```
get system status
```
Expected: Hostname `FG-LAB-01`, FortiOS `7.6.6`, license `Valid`, correct time zone.

**Interface state:**
```
get system interface physical
```
Expected: `mgmt` is `up`, all others are `down` (no cables connected yet to data ports).

**Interface configuration:**
```
show system interface
```
Expected: `mgmt` with 192.168.1.99/24, `port1` with 203.0.113.2/30, all others at default.

**DNS:**
```
show system dns
```
Expected: Primary 8.8.8.8, secondary 8.8.4.4.

**NTP:**
```
show system ntp
```
Expected: `ntpsync enable`, two NTP servers configured.

**Admin account:**
```
show system admin
```
Expected: `admin` account listed. Password line will show an encrypted hash — not the plaintext value.

### 8.2 End-State Configuration Summary

```
config system global
    set hostname FG-LAB-01
    set timezone 12
    set admintimeout 60
end

config system admin
    edit admin
        set password <encrypted>
    next
end

config system interface
    edit mgmt
        set ip 192.168.1.99 255.255.255.0
        set allowaccess ping https ssh
        set description "OOB Management - Lab"
    next
    edit port1
        set ip 203.0.113.2 255.255.255.252
        set allowaccess ping
        set description "WAN - Upstream ISP/Router"
        set role wan
    next
end

config system dns
    set primary 8.8.8.8
    set secondary 8.8.4.4
    set domain lab.local
end

config system ntp
    set ntpsync enable
    set type custom
    config ntpserver
        edit 1
            set server 0.pool.ntp.org
        next
        edit 2
            set server 1.pool.ntp.org
        next
    end
end
```

---

## Key Takeaways — Cisco to FortiOS Translation

| Concept | Cisco IOS | FortiOS 7.6.6 |
|---|---|---|
| Auto-save | `write memory` (manual) | Automatic on `end` — no command needed |
| Hostname | `hostname <name>` | `config system global` → `set hostname` |
| Admin password | `enable secret` / `username admin secret` | `config system admin` → `edit admin` → `set password` |
| Interface IP | `ip address x.x.x.x y.y.y.y` | `config system interface` → `edit <port>` → `set ip x.x.x.x y.y.y.y` |
| Interface description | `description <text>` | `set description <text>` inside interface edit |
| Management access | `transport input ssh` + `ip http secure-server` | `set allowaccess ping https ssh` on the interface |
| DNS | `ip name-server x.x.x.x` | `config system dns` → `set primary x.x.x.x` |
| NTP | `ntp server x.x.x.x` | `config system ntp` → `config ntpserver` → `set server x.x.x.x` |
| Exec timeout | `exec-timeout 60 0` | `config system global` → `set admintimeout 60` |

---

## Common Mistakes at This Stage

**Forgetting that `end` saves immediately.** If you typed a wrong IP and hit `end`, the wrong IP is now live. Fix it by re-entering the config tree.

**Typing `allowaccess` like a Cisco access-class.** In FortiOS, `set allowaccess` is a space-separated list of protocols. Adding a new protocol is done by listing all protocols you want — you cannot append:
- Wrong: `set allowaccess snmp` (removes everything else, leaves only SNMP)
- Right: `set allowaccess ping https ssh snmp` (keeps the existing ones and adds SNMP)

**Expecting `no` to undo things.** FortiOS does not have a `no` command. To remove a specific attribute, use `unset <attribute>`. To remove a specific value from a list, you must restate the full list without the unwanted value.

**Blocking yourself out of HTTPS.** If you accidentally set `allowaccess ping` only on the mgmt interface and lost HTTPS access, use your console session to correct it.

---

## Instructor Notes

> *For the workshop facilitator.*

**Task timing:** This module runs 45–60 minutes with a Cisco-background audience. The CLI orientation discussion in Task 1 generates the most questions — especially around `end` auto-saving and the absence of `no` commands. Budget extra time here.

**Common participant friction:**
- Participants will type `enable` at the FortiGate prompt out of muscle memory. Explain there is no privileged exec mode — they are already at full privilege.
- Some will try `ip address` syntax inside an interface. Remind them the FortiOS equivalent is `set ip <address/mask>` with a space-separated mask, not a slash.
- The `set allowaccess` overwrite behavior surprises everyone. Use it as a teaching moment about FortiOS's `set` semantics — every `set` replaces the entire value, not appends to it.

**Lab variant — if WAN uplink is live:**
If the upstream router is already connected and reachable, have participants test DNS and NTP reachability at the end of this module:
```
execute ping 8.8.8.8
execute ping update.fortiguard.net
```
Successful ping to 8.8.8.8 confirms WAN IP and routing. Successful ping to update.fortiguard.net confirms DNS is resolving.

**About the timezone value:** The FortiOS timezone integer corresponds to a fixed offset, not a named zone. Run `set timezone ?` in the global config to show the full list to the class — it's a good way to demonstrate the `?` help system.

**GUI exploration:** After Task 7, give participants 5–10 minutes of free exploration in the GUI. The Dashboard widget for "Security Fabric" will show the FortiGate icon alone (no FortiSwitch or FortiAP yet). This is the baseline they'll watch populate as the workshop progresses.

---

## Module 01 Complete

**Checkpoint:** Before moving to Module 02, confirm:
- [ ] `get system status` shows hostname `FG-LAB-01` and FortiOS 7.6.6
- [ ] Admin password is set and you can log in successfully
- [ ] `show system interface` shows mgmt (192.168.1.99/24) and port1 (203.0.113.2/30)
- [ ] `show system dns` shows 8.8.8.8 primary
- [ ] `show system ntp` shows ntpsync enabled with two servers
- [ ] GUI accessible at https://192.168.1.99

**Next:** [Module 02 — Interfaces, Zones, and VLANs](Module-02-Interfaces-Zones-VLANs.md)

---

*All CLI commands in this document are verified against the FortiOS 7.6.6 CLI Reference (Fortinet Inc., 2026-01-28).*

| Command Section | CLI Reference Page |
|---|---|
| `config system global` | p.1532 |
| `config system admin` | p.1400 |
| `config system interface` | p.1620 |
| `config system dns` | p.1482 |
| `config system ntp` | p.1874 |
