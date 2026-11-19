# Terifier Sentinel — X post for submission (format: @say_more_gm)

Modelled on the @say_more_gm #NEARHackathon post (18 Nov 2026):
hook question → "30 seconds on how X does it, built during #Hackathon" →
"the full breakdown ↓" → attached 30-second video with bold statement
frames + a comparison chart → reply thread with the full breakdown link.

Post it from @0xkames. Video is a storyboard only — record it with the
screen captures in docs/DEMO.md (origin tx → Lasna Tripped → callbacks).

---

## Main post (copy-paste, 278 characters)

```
how do you protect your wallet when you're not watching it?

30 seconds on how Terifier does it, built during #ReactiveOmniBuildathon 🛡️

the full breakdown ↓
```

Attach the 30-second video (storyboard below).

---

## Reply 1 — the breakdown (post as a reply to the main post)

```
Terifier Sentinel is a cross-chain wallet watchdog on Reactive Lasna.

One bad approval, one bad transfer, or 10 minutes of silence — and it trips
exactly once, then Reactive callbacks a rescuer on every chain that pulls
your remaining tokens to safety. No bot. No server. No key online.

Track: Set It and Forget It
Live on Lasna + Base Sepolia + Unichain Sepolia ↓
```

## Reply 2 — contracts + links

```
Contracts (testnet, verified on-chain):
• Reactive (Lasna): 0x298902E4ec5C6C1Fc596C73699F70F02Ee96Fe95
• Rescuer (Base + Unichain Sepolia): 0xbe9F377e91e1b7a183AC9c344Eb776c4644F9A9F
• Demo token tUSD: 0x298902E4ec5C6C1Fc596C73699F70F02Ee96Fe95

Repo: https://github.com/wadezigh96/Terifier
DoraHacks: https://dorahacks.io/hackathon/reactive-omni-buildathon
```

## Reply 3 — what makes it different

```
Why not just an allowlist bot?

• Reason-coded trips: BAD_APPROVAL / BAD_TRANSFER / INACTIVITY
• CRON dead-man switch — silence itself is a trip
• Arm / disarm / trip-once latch + owner reset
• Per-token rescue, min(balance, allowance), one bad token can't block the rest

18/18 Foundry tests. Armed and live.
```

---

## 30-second video — storyboard (mirrors the example's bold-frame style)

| Time | Frame text (bold, full screen) | Visual |
| --- | --- | --- |
| 0–4s | A WALLET IS NOT SAFE JUST BECAUSE YOU'RE CAREFUL. | Wallet UI, approval prompt |
| 4–8s | ONE BAD APPROVAL DRAINS EVERYTHING. | Approval to unknown spender, balance → 0 |
| 8–13s | BOTS WATCH. THEY DON'T ACT. | Comparison chart: manual monitoring / bot alerts vs Terifier Sentinel |
| 13–19s | TERIFIER TRIPS ONCE. THEN IT RESCUES. | Flow: Bad approval → Lasna `Tripped` (reason 1) → callback → tokens land in safe address |
| 19–25s | TWO CHAINS. ONE WATCHDOG. ZERO SERVERS. | Base Sepolia + Unichain Sepolia → Lasna → safe address |
| 25–30s | SET IT AND FORGET IT. | Terifier Sentinel logo/title + repo link + #ReactiveOmniBuildathon |

Voiceover (read over the frames, ~30s):
"How do you protect your wallet when you're not watching it? One bad
approval drains everything, and bots only watch. Terifier Sentinel is a
reactive contract on Lasna. A bad approval trips it once, and it rescues
your tokens on Base and Unichain to safety — no bot, no server, no key
online. Set it and forget it."

---

## DoraHacks submission (same story, formal version)

Title: Terifier Sentinel — cross-chain wallet watchdog (set it and forget it)
Track: Set It and Forget It
Description: see docs/SUBMISSION.md. Repo, deployed addresses and deploy tx
hashes are in docs/DEPLOY_ADDRESSES.md. Demo video: the 30-second video
above (plus the <3 min full demo in docs/DEMO.md once recorded).
