# Terifier Sentinel — DoraHacks submission fields

Hackathon: Reactive Omni Buildathon · Track: **Set It and Forget It** (one track only)
Submission window: 5 Nov 2026 19:00 – 6 Dec 2026 03:00 WIB (UTC+7)

## Title

Terifier Sentinel — cross-chain wallet watchdog (set it and forget it)

## Description (paste into DoraHacks)

Terifier Sentinel protects one wallet on two chains at once, with no bot, no
server, and no key online. A reactive contract on Reactive Lasna watches ERC-20
Approval and Transfer events for the wallet on Base Sepolia and Unichain
Sepolia, plus a CRON dead-man switch. A bad approval (spender not allowlisted),
a bad transfer (recipient not allowlisted), or wallet inactivity past a
configurable threshold trips the watchdog exactly once — reason-coded
(BAD_APPROVAL / BAD_TRANSFER / INACTIVITY) — and Reactive Network callbacks a
rescuer on every wired chain, which pulls min(balance, allowance) per token
(max 16, per-token try/catch so one bad token cannot block the rest) into a
safe address. Benign activity to allowlisted addresses just resets the
inactivity clock. Arm/disarm + trip-once latch + owner reset; ERC-20 only;
testnet only.

How it differs from Tripwire (same track): reason-coded trips, a CRON
dead-man switch, arm/disarm/reset + trip-once latch, allowlist for spenders
AND recipients, and per-token rescue caps with isolated failures.

## Links

- Public GitHub repo: https://github.com/wadezigh96/Terifier
- Demo video (< 3 min): TODO — see docs/DEMO.md for the script
- Live demo: TODO (optional)

## Deployed contract addresses — deployed + verified 2026-11-19, armed

| Contract | Chain | Chain ID | Address |
| --- | --- | --- | --- |
| TerifierReactive | Reactive Lasna | 5318007 | `0x298902E4ec5C6C1Fc596C73699F70F02Ee96Fe95` |
| TerifierRescuer | Base Sepolia | 84532 | `0xbe9F377e91e1b7a183AC9c344Eb776c4644F9A9F` |
| TerifierRescuer | Unichain Sepolia | 1301 | `0xbe9F377e91e1b7a183AC9c344Eb776c4644F9A9F` |
| MockToken (tUSD, demo) | Base Sepolia | 84532 | `0x298902E4ec5C6C1Fc596C73699F70F02Ee96Fe95` |
| MockToken (tUSD, demo) | Unichain Sepolia | 1301 | `0x298902E4ec5C6C1Fc596C73699F70F02Ee96Fe95` |

Deploy txs: reactive `0xd4f8dcb4a88236a82b7cc09fe9cab8ff0e78ca0275184ada3d4352359972aecc`
(Lasna); Base rescuer `0xffdc840d7d19f31d20a3dab37dc6828f9e282e94fdde3115359f99cefb657d28`,
Unichain rescuer `0x652d26fc41b358e3c95f50938d583787a059ff9f5d3c9c3089b566603036552d`;
`arm()` `0x962887aaef2fb38d01f7b80db6b0eaea2b0c4758dd88c06aa906614f6cd6b2e6`.
Full list in docs/DEPLOY_ADDRESSES.md. Verified: armed, threshold 600s,
both rescuers wired, both tokens watched, 1000 tUSD allowance per chain.

## Transaction hashes — full loop, origin event → callback (TODO)

| Step | Chain | Tx hash |
| --- | --- | --- |
| Bad approval (origin event) | Base Sepolia | TODO |
| `react()` / `Tripped` (reason 1) | Reactive Lasna | TODO |
| `rescue()` callback | Base Sepolia | TODO |
| `rescue()` callback | Unichain Sepolia | TODO |

## Team

- TODO: list all team members in the DoraHacks submission.
- Language: submission in English.

## Pre-submit checks

- [ ] Repo is public and open-source (MIT).
- [ ] `forge build` clean, `forge test` 18/18 passing.
- [ ] Contracts deployed to the networks specified in the track (Lasna + Base/Unichain Sepolia).
- [ ] Rescuers wired (`setRescuer`) and contract armed; funding covers react + callbacks.
- [ ] Demo video under 3 minutes, showing origin tx → Lasna `Tripped` → callback txs → rescued balances.
- [ ] Exactly one track selected; no project built before the hackathon is submitted.
