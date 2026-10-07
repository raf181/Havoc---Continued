# Defensive CTI Classroom Edition

> [!CAUTION]
> **Classroom authorization only.** This repository may be used only for instructor-led CTI, detection-engineering, incident-response, and malware-analysis exercises on explicitly named lab virtual machines. Any use outside the written class scope—including use on public networks, production systems, third-party systems, or devices without the owner's explicit permission—is prohibited and is not authorized by the instructor or repository maintainer.

> [!WARNING]
> Havoc contains command-and-control, process-injection, token, and defense-evasion capabilities. Treat generated artifacts as malware. Never expose the Teamserver or a listener to the Internet, and never move artifacts to personal or production devices.

<div align="center">
  <img width="125px" src="assets/Havoc.png" />
  <h1>Havoc</h1>
  <br/>

  <p><i>Havoc is a modern and malleable post-exploitation command and control framework, created by <a href="https://twitter.com/C5pider">@C5pider</a>.</i></p>
  <br />

  <img src="assets/Screenshots/FullSessionGraph.jpeg" width="90%" /><br />
  <img src="assets/Screenshots/MultiUserAgentControl.png" width="90%" /><br />
  
</div>

### Quick Start

> For this fork, use the **Defensive classroom lab guide** below. The upstream wiki is reference material only and does not override this repository's classroom scope or safety controls.

This checkout uses a version-matched bundled MinGW toolchain. A newer system compiler is not necessarily compatible. Validate the specific classroom snapshot and toolchain before class rather than upgrading components during an exercise.

The upstream [Installation](https://havocframework.com/docs/installation) and [Known Issues](https://github.com/HavocFramework/Havoc/wiki#known-issues) pages may help with compatibility research, but do not follow any step that expands the written lab scope.

---

### Features

#### Client

> Cross-platform UI written in C++ and Qt

- Modern, dark theme based on [Dracula](https://draculatheme.com/)


#### Teamserver

> Written in Golang

- Multiplayer
- Payload generation (exe/shellcode/dll)
- HTTP/HTTPS listeners
- Customizable C2 profiles 
- External C2

#### Demon

> Havoc's flagship agent written in C and ASM

- Sleep Obfuscation via [Ekko](https://github.com/Cracked5pider/Ekko), Ziliean or [FOLIAGE](https://github.com/SecIdiot/FOLIAGE)
- x64 return address spoofing
- Indirect Syscalls for Nt* APIs
- SMB support
- Token vault
- Variety of built-in post-exploitation commands
- Patching Amsi/Etw via Hardware breakpoints
- Proxy library loading
- Stack duplication during sleep. 

<div align="center">
  <img src="assets/Screenshots/SessionConsoleHelp.png" width="90%" /><br />
</div>

#### Extensibility

- [External C2](https://github.com/HavocFramework/Havoc/wiki#external-c2)
- Custom Agent Support
  - [Talon](https://github.com/HavocFramework/Talon)
- [Python API](https://github.com/HavocFramework/havoc-py)
- [Modules](https://github.com/HavocFramework/Modules)

---

### Community

You can join the official [Havoc Discord](https://discord.gg/z3PF3NRDE5) to chat with the community! 

### Note

Please do not open any issues regarding detection. 

The Havoc Framework hasn't been developed to be evasive. Rather it has been designed to be as malleable & modular as possible. Giving the operator the capability to add custom features or modules that evades their targets detection system. 

---

## Defensive classroom lab guide

This guide covers safe lab preparation, Teamserver/client setup, Windows telemetry, SIEM validation, troubleshooting, and cleanup. It intentionally does **not** document agent generation or delivery, credential access, persistence, lateral movement, security-control bypasses, or post-exploitation.

### Authorization and rules of engagement

Before class, the instructor must record:

- Authorized instructors and students.
- The exact Kali, Windows, and SIEM VMs in scope.
- The class start and end times.
- The VMware host-only subnet and permitted ports.
- Permitted exercises and prohibited actions.
- Evidence handling, retention, and cleanup requirements.

The following are prohibited:

- Bridged networking, Internet-facing listeners, port forwarding, or public/cloud targets.
- Use against any system not explicitly listed in the written authorization.
- Real credentials, personal data, business data, or production accounts in the lab.
- Credential dumping, token theft, persistence, lateral movement, privilege escalation, or data collection.
- Disabling or bypassing Defender, AMSI, ETW, EDR, logging, or other security controls.
- Delivery through email, websites, shared drives, removable media, or third-party services.

Authorization must come from the system owner. This notice does not replace consent or applicable law.

### Recommended architecture

```text
VMware host-only network — no bridge and no port forwarding

Kali instructor VM                 Windows 11 student VM
Teamserver + client                Defender + Sysmon + SIEM agent
TCP 40056 management              Synthetic users and test data only
TCP 8443 lab listener
             \                    /
              \                  /
                Optional SIEM VM
```

Safety controls:

- Use VMware **Host-only** networking only.
- Disable shared folders, drag-and-drop, and shared clipboard while handling artifacts.
- Take clean snapshots before every class.
- Keep host firewalls and Windows security controls enabled.
- Use a nonprivileged listener port such as `8443`.
- Revert the Windows VM after every exercise.

### Kali prerequisites

This checkout expects:

- Repository path: `~/Havoc` (or another instructor-controlled directory).
- Executables: `havoc` and `client/Havoc`.
- `nasm` and the bundled MinGW compilers below `data/`.
- A Kali host-only IPv4 address reachable from Windows.

Validate the environment:

```bash
cd ~/Havoc
ip -br -4 addr
./havoc --help
test -x data/x86_64-w64-mingw32-cross/bin/x86_64-w64-mingw32-gcc
test -x data/i686-w64-mingw32-cross/bin/i686-w64-mingw32-gcc
```

VMware DHCP addresses may change after a reboot or snapshot restore. Never reuse a bind address without checking it first.

### Windows 11 telemetry prerequisites

Keep security controls enabled and collect at least:

- Microsoft Defender Antivirus operational events.
- Windows Security logs, including process creation where configured.
- PowerShell operational and script-block logs.
- Sysmon process, network, image-load, process-access, file, registry, and DNS events selected by an instructor-reviewed configuration.
- SIEM/log-forwarder health events.

Official references:

- [Microsoft Sysmon](https://learn.microsoft.com/sysinternals/downloads/sysmon)
- [PowerShell logging on Windows](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_logging_windows)
- [Windows security auditing](https://learn.microsoft.com/windows/security/threat-protection/auditing/advanced-security-auditing-faq)
- [Microsoft Defender Antivirus events](https://learn.microsoft.com/defender-endpoint/troubleshoot-microsoft-defender-antivirus)

Do not blindly install a Sysmon configuration copied from the Internet. Review its coverage, privacy impact, and expected event volume first.

Verify the sensors from an elevated PowerShell window on the Windows lab VM:

```powershell
Get-MpComputerStatus | Select-Object AntivirusEnabled, RealTimeProtectionEnabled
Get-Service Sysmon64 -ErrorAction SilentlyContinue
Get-WinEvent -LogName 'Microsoft-Windows-Sysmon/Operational' -MaxEvents 5
Get-WinEvent -LogName 'Microsoft-Windows-PowerShell/Operational' -MaxEvents 5
auditpol.exe /get /subcategory:'Process Creation'
```

Resolve missing logs or unhealthy sensors before introducing any simulation activity.

### SIEM prerequisites

The class can use Microsoft Sentinel, Splunk, Elastic, Security Onion, or another approved SIEM. Before any simulation, verify ingestion of:

- Windows Security events.
- `Microsoft-Windows-Sysmon/Operational`.
- `Microsoft-Windows-PowerShell/Operational`.
- Microsoft Defender operational events.
- DNS, firewall, proxy, or packet metadata for the host-only subnet, if available.

Record normal ingestion latency so delayed events are not mistaken for missing detections.

### 1. Secure permissions

Run Havoc as the normal `anoam` account. Do not use `sudo`; it creates root-owned databases and evidence directories.

```bash
cd ~/Havoc
chmod 700 data/loot
chmod 600 data/server.key data/teamserver.db
chmod 644 data/server.cert
chmod 600 profiles/havoc.yaotl data/havoc.yaotl
```

If runtime files are already root-owned, an administrator should return only the affected files to the dedicated lab account. Never use `chmod -R 777`.

#### Guarded automated setup

The repository includes a safety-gated setup helper. It generates unique local credentials, creates a private classroom profile, validates the bundled toolchain, backs up prior state when requested, and can start the Teamserver. It refuses root execution, the default-route interface, and non-RFC1918 addresses.

First add a dedicated VMware host-only adapter to Kali and identify its interface with `ip -br -4 addr`. Then run:

```bash
cd ~/Havoc
./scripts/setup-classroom-lab.sh \
  --accept-classroom-policy \
  --interface eth1 \
  --fresh-state \
  --start-server
```

Replace `eth1` with the actual dedicated host-only interface. Generated credentials are stored in `data/classroom-credentials.txt` with mode `600`; the generated profile is `profiles/classroom.generated.yaotl` and is excluded from Git.

The helper does not create listeners or agents, deliver artifacts, or change Windows security controls. Those boundaries are intentional.

### 2. Configure the classroom profile

Review `profiles/havoc.yaotl` before class:

- Replace every example operator and service password.
- Keep Teamserver management on private port `40056` unless the lab design specifies another port.
- Store credentials in the approved instructor secret store, not in slides or public commits.
- Confirm the compiler paths refer to the bundled toolchains under `data/`.

Never commit classroom passwords, private keys, Teamserver databases, loot, or generated artifacts.

### 3. Start the Teamserver

Havoc resolves profiles, databases, payload directories, and logs from its working directory, so always start it from the repository root:

```bash
cd ~/Havoc
./havoc server --profile profiles/havoc.yaotl --verbose
```

Expected output includes:

```text
Starting Teamserver on wss://0.0.0.0:40056
Teamserver logs saved under: data/loot/...
```

Do not use `./havoc server -d` for this classroom checkout. That option loads `data/havoc.yaotl`, which may select an incompatible system MinGW version instead of the bundled compiler.

### 4. Start and connect the client

In a separate terminal:

```bash
cd ~/Havoc
./havoc client
```

Create a fresh connection using:

- Host: `127.0.0.1` when the client is on the same Kali VM.
- Port: `40056`.
- Username and password: the values in `profiles/havoc.yaotl`.

The client pre-fills an example password of `password`; it is not synchronized with the Teamserver profile. Replace it. Continue only after the server logs a successful operator authentication.

### 5. Create an isolated classroom listener

From an authenticated client, create a uniquely named listener:

- Bind host: Kali's current host-only IPv4 address.
- Bind port: `8443` or another instructor-approved nonprivileged port.
- Connection host: the same host-only IPv4 address.
- Connection port: the same approved port.
- Prefer the specific host-only address over `0.0.0.0`.
- Never use a public, bridged, NAT-forwarded, or production address.

Verify only the expected lab ports are listening:

```bash
ss -ltnp | rg ':40056|:8443'
```

### Detection-focused class workflow

#### Phase 1: Establish a baseline

Collect at least ten minutes of normal Windows activity before the exercise. Identify:

- Normal parent/child process relationships.
- Expected DNS resolvers and network destinations.
- Typical PowerShell and command-shell activity.
- Normal Defender and Sysmon volume.
- SIEM ingestion latency and host identity fields.

#### Phase 2: Observe authorized activity

Only the instructor performs the separately approved simulation. Students monitor telemetry. Useful sources include:

| Data source | Events or behavior to review |
| --- | --- |
| Sysmon | Process creation (1), network connections (3), image loads (7), remote threads (8), process access (10), file creation (11), registry changes (12–14), DNS queries (22) |
| Windows Security | Process creation (4688), logons (4624/4625), explicit credentials (4648), service installation (4697), where auditing is enabled |
| PowerShell | Engine/provider events and script-block events such as 4104 |
| Defender | Detection, remediation, configuration-change, and health events |
| Network | Repeated connections, unusual TLS destinations, unexpected ports, and periodic timing |

Not every event appears on every system. Validate audit policy and sensor configuration before concluding that telemetry was bypassed.

#### Phase 3: Build behavior-based detections

Suggested defensive objectives:

- Detect an unusual process making recurring outbound connections.
- Identify unexpected parent/child process relationships.
- Alert on access to another process with rights associated with memory inspection or injection.
- Find unsigned or unusual modules loaded into a trusted process.
- Identify PowerShell or shell usage inconsistent with the baseline.
- Correlate a network event, process event, and Defender/Sysmon event on one host.

Every detection should document its data source, audit prerequisites, query logic, likely false positives, severity, response action, and validation evidence.

#### Phase 4: Investigate and report

Student reports should include:

1. The earliest relevant event.
2. The process tree and command-line context.
3. Available user, integrity, hash, signature, and path data.
4. Network destinations and timing.
5. Defender, Sysmon, and SIEM corroboration.
6. A clear separation between observations and assumptions.
7. Containment and recovery recommendations for a real environment.

Never submit live artifacts, private keys, credentials, or raw memory captures to public services.

### Troubleshooting

#### Listener restores an old IP

Listeners are persisted in `data/teamserver.db`. Delete or edit stale listeners through an authenticated client and recreate them with the current host-only address.

For a new class with no state to preserve, stop the Teamserver and make a recoverable backup:

```bash
mv data/teamserver.db data/teamserver.db.previous-class
```

Restarting creates a clean database. Retain the backup only according to the evidence policy.

#### Client authentication fails

- Ensure the client and server use the same profile credentials.
- Credentials are case-sensitive.
- Replace the client's pre-filled example password.
- Do not administer listeners until the server logs successful authentication.

#### `bind: cannot assign requested address`

The listener references an address that Kali does not currently own. Check `ip -br -4 addr` and select the current host-only address. Do not expose the listener through a public or bridged interface.

#### Permission errors or root-owned logs

Stop using `sudo`. Restore ownership only for affected runtime files and restrict the database, profiles, private key, and loot to the dedicated lab account.

#### Compiler errors involving `__stosb`, pointer types, or `SysInvoke`

The checkout and system MinGW version are incompatible. Use the explicit classroom profile and bundled compilers. Do not broadly suppress compiler diagnostics or copy patched binaries from untrusted sources.

#### Python `invalid escape sequence` warning

Some optional client modules contain older Python string syntax. This warning is unrelated to Teamserver authentication or listener binding. Disable unnecessary modules rather than weakening system security.

### Cleanup after every class

1. Stop the client and Teamserver.
2. Confirm ports `40056` and `8443` are closed.
3. Export only the logs authorized for the lesson.
4. Store evidence in the approved location with access controls and retention dates.
5. Rotate or remove temporary classroom credentials.
6. Revert the Windows and artifact-handling VMs to clean snapshots.
7. Confirm all VMware adapters remain host-only and no forwarding rules were added.
8. Delete artifacts when the approved retention period ends.

### Instructor preflight checklist

- [ ] Written authorization identifies participants, VMs, subnet, actions, and class times.
- [ ] Clean snapshots exist and have been tested.
- [ ] Networking is host-only, with no bridge or port forwarding.
- [ ] Defender and required Windows logs remain enabled.
- [ ] Sysmon and the SIEM agent are healthy.
- [ ] Test events reach the SIEM before class.
- [ ] Default passwords have been replaced.
- [ ] Havoc runs as a non-root lab account.
- [ ] The listener uses only the host-only address and approved port.
- [ ] Students understand evidence handling and cleanup.
- [ ] The instructor can terminate the exercise immediately if scope is exceeded.

### Upstream attribution

Havoc was created by [C5pider](https://twitter.com/C5pider). Refer to the upstream licensing and notices for applicable terms. This classroom guide adds safety expectations for this lab; it does not grant permission to use systems you do not own or administer.
