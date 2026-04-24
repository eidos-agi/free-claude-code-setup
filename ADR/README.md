# Architecture Decision Records

Why-we-did-it-this-way. Each ADR captures a decision we made, the constraint that forced it, alternatives we rejected, and when to revisit. Short by design — 5-15 sentences each.

| # | Decision | Constraint |
|---|----------|------------|
| [0001](0001-wsl1-not-wsl2.md) | Use WSL1, not WSL2 | Shadow PC has no nested virt |
| [0002](0002-pin-claude-code-2.1.81.md) | Pin `claude-code@2.1.81` | 2.1.83+ Bun ELF broken on WSL1 |
| [0003](0003-launcher-owns-auth-isolation.md) | Launcher owns auth isolation | Three silent auth pitfalls |
| [0004](0004-bootstrap-skips-apt-if-possible.md) | Bootstrap skips apt when possible | WSL1 systemd reconfigure trap |
| [0005](0005-softer-proof-not-tcpdump.md) | V2 uses composed softer proofs | tcpdump unavailable, iptables risky on WSL1 |

## When to add a new one

Add an ADR when a decision is:
- Non-obvious to someone reading the code cold
- Driven by a constraint that's not visible from the file you changed
- Likely to come up again ("why didn't we just...")
- Something you'd want to re-evaluate later

Don't add ADRs for: trivial style choices, self-evident structural decisions, anything one-line commit messages cover.
