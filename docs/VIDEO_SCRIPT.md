# Terifier Sentinel — Video Script to Win (under 3 minutes)

Target: **2:50, never over 3:00** (DoraHacks / Reactive blog limit).
Language: **English** (submission must be in English). Record the screen with
terminal + explorers visible. Narration is verbatim — read it as written.

This script covers *everything* built and deployed on 19 Nov 2026, in the
order it happened, so the judges see the full story, not just a demo:
research → track choice → build → tests → faucets → deploy → verify →
live attack → rescue. Nothing in it is invented: every address and tx hash
below was verified on-chain. The only blanks are the live-demo tx hashes —
fill those in after you record the attack (see §5).

Explorers:

- Lasna: https://lasna.reactscan.net/
- Base Sepolia: https://sepolia.basescan.org/
- Unichain Sepolia: https://sepolia.uniscan.xyz/

---

## 0. Before recording — checklist (off-camera)

- [x] Contracts deployed, wired, armed (see §3 for the proof shots).
- [x] Open 3 explorer tabs: reactive on Lasna, rescuer + token on Base,
      rescuer + token on Unichain. Safe address balance = 0 on both chains.
- [x] Watched wallet: 1000 tUSD on Base + 1000 tUSD on Unichain, 1000 tUSD
      allowance to each rescuer. `armed() == true`, `tripped() == false`.
- [x] Attacker address ready (any address NOT allowlisted, e.g.
      `0x000000000000000000000000000000000000dEaD` — do NOT use the safe
      address). Have the `approve(attacker, max)` call pre-filled in
      MetaMask / cast, ready to send.
- [x] **Trip-once warning:** the watchdog fires exactly once, then latches.
      If a take goes wrong, call `resetTrip()` then `arm()` on Lasna before
      re-recording — do NOT redeploy. The 600 s CRON threshold also means a
      second take 10 minutes after arming can trip on INACTIVITY instead;
      re-arm right before the attack take.

---

## 1. Hook — 0:00–0:15

**On screen (bold, full screen):** `A WALLET IS NOT SAFE JUST BECAUSE YOU'RE CAREFUL.`

**Narration:**

> "How do you protect your wallet when you're not watching it? One bad
> approval drains everything — and bots only watch. This is Terifier
> Sentinel, built for the Reactive Omni Buildathon, track Set It and
> Forget It."

**Show:** MetaMask approval prompt to an unknown spender, then a wallet
balance dropping to zero (stock / animated, not your real wallet).

## 2. The idea — 0:15–0:45

**On screen:** architecture diagram (README): \`Base Sepolia + Unichain
Sepolia → Reactive Lasna → callback → safe address\`.

**Narration:**

> "Terifier is a reactive contract on Reactive Lasna. It watches one wallet
> on Base Sepolia and Unichain Sepolia — every Approval, every Transfer —
> plus a CRON dead-man switch. A bad approval, a bad transfer, or ten
> minutes of silence trips it exactly once, reason-coded, and Reactive
> callbacks a rescuer on every chain, which pulls your remaining tokens to
> a safe address. No bot. No server. No key online."

**Show:** the three reason codes on screen: `1 BAD_APPROVAL · 2 BAD_TRANSFER · 3 INACTIVITY`.

## 3. What we built — 0:45–1:15 (the work, fast)

**Narration:**

> "Built from scratch during the hackathon. Three contracts: TerifierReactive
> on Lasna, TerifierRescuer on each destination chain, and a demo token.
> Eighteen Foundry tests, eighteen passing — bad approvals trip once,
> benign approvals don't, the CRON switch fires after the threshold, and
> the rescuer only ever moves the minimum of balance and allowance."

**Show (quick cuts, 5 s each):**

1. Terminal: `forge test` → `18 passed; 0 failed`.
2. `src/` listing: `TerifierReactive.sol`, `TerifierRescuer.sol`,
   `MockToken.sol`, `test/Terifier.t.sol`.
3. Comparison table vs the same-track allowlist-only project Tripwire:
   reason-coded trips ✓ · CRON dead-man switch ✓ · arm/disarm + trip-once
   latch ✓ · allowlist for spenders AND recipients ✓ · per-token rescue
   with isolated failures ✓.

## 4. It is really deployed — 1:15–1:45 (proof, not promises)

**Narration:**

> "And it is really deployed — not a local test. Sepolia ETH became
> lREACT, the reactive contract went live on Lasna, and a rescuer went
> live on each chain. Wired, funded, approved, and armed."

**Show (explorer screenshots, with tx hashes on screen):**

- lREACT conversion: `0xf5eb0c0d…a483820` — 0.051 Sepolia ETH → 5.355 lREACT.
- Reactive (Lasna) `0x298902E4ec5C6C1Fc596C73699F70F02Ee96Fe95`,
  deploy tx `0xd4f8dcb4…9972aecc`.
- Rescuer (Base + Unichain) `0xbe9F377e91e1b7a183AC9c344Eb776c4644F9A9F`,
  deploy txs `0xffdc840d…657d28` and `0x652d26fc…36552d`.
- `arm()` tx `0x962887aa…6b2e6`. Then a live `cast call` showing
  `armed() == true`, `tripped() == false`, threshold `600`,
  reactive balance ≈ 1.005 lREACT, allowance 1000 tUSD on both chains.
- One honest line on screen: "Unichain's RPC kept dropping Foundry's
  TLS handshake, so that leg was deployed with cast, legacy transactions,
  and retries — same bytecode, same tests."

## 5. The live attack — 1:45–2:30 (the full loop, this is the score)

**Narration:**

> "Now the attack, live. The watched wallet holds one thousand demo
> dollars on each chain. The safe address holds zero. Watch what happens
> when the wallet approves an attacker."

**Show, in order — pause on each tx hash so the judges can read it:**

1. **Origin event (Base Sepolia):** send `approve(ATTACKER, max)` on tUSD
   from the watched wallet. Tx hash: `______________________` \*(fill in
   after recording)\*.
2. **Reactive (Lasna):** the `Tripped` event, reason `1`, chain `84532`,
   then the callback requests to both rescuers. Tx hash:
   `______________________`.
3. **Callback (Base Sepolia):** `rescue()` from the callback proxy,
   `Rescued` event. Tx hash: `______________________`.
4. **Callback (Unichain Sepolia):** same `rescue()`, same `Rescued`.
   Tx hash: `______________________`.

**Narration (over the callbacks):**

> "One bad approval. Lasna trips. Two chains rescue — at the same time."

## 6. The result — 2:30–2:50

**Narration:**

> "The safe address now holds the rescued tokens on both chains. The
> watched wallet is empty. And the watchdog fired once and latched —
> `tripped` is true, `armed` is false — so it can never double-fire or
> be re-triggered by the same attack. The other two legs work the same
> way: a bad transfer trips reason two, and silence trips reason three
> through CRON."

**Show:** safe balance before (0) → after (1000 tUSD per chain);
`tripped() == true`, `armed() == false`.

## 7. Close — 2:50–3:00

**On screen (bold):** `ONE WALLET. TWO CHAINS. ZERO BOTS.`

**Narration:**

> "One wallet, two chains, zero bots. Terifier Sentinel — set it and
> forget it."

**On screen:** repo `github.com/wadezigh96/Terifier` · track
`Set It and Forget It` · #ReactiveOmniBuildathon.

---

## 30-second teaser cut (for X, same as docs/X\_POST.md)

Hook question → "30 seconds on how Terifier does it, built during
#ReactiveOmniBuildathon 🛡️" → "the full breakdown ↓".
Use §1 + §5 only: frames "A WALLET IS NOT SAFE JUST BECAUSE YOU'RE
CAREFUL." / "ONE BAD APPROVAL DRAINS EVERYTHING." / "TERIFIER TRIPS ONCE.
THEN IT RESCUES." / "SET IT AND FORGET IT." — then link the full video
and the repo in the reply thread.

---

## Why this script is built to win (judging criteria)

- **Usefulness:** a real wallet problem (one bad approval = drained),
  solved for a wallet the user already owns, on two chains at once.
- **Creativity:** reason-coded trips + CRON dead-man switch + trip-once
  latch — none of which the same-track allowlist-only entry has.
- **Reactive Integration:** the whole loop is Reactive — origin event →
  Lasna `react()` → callback → `rescue()`. Every step is shown on-chain
  with real tx hashes; nothing is simulated.
- **Quality:** 18/18 tests, verified live state, honest about the one
  hard part (Unichain RPC) and how it was fixed, and the demo is
  reproducible from the README.