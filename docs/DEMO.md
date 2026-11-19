# Terifier Sentinel — demo script (under 3 minutes)

Target video length: **under 3 minutes**. Record the screen with the terminal
and the explorers visible. All values below are the demo defaults from
`script/Deploy.s.sol` (MockToken `tUSD`, 1000 tUSD in the watched wallet).

Explorers:
- Lasna: https://lasna.reactscan.net/
- Base Sepolia: https://sepolia.basescan.org/
- Unichain Sepolia: https://sepolia.uniscan.xyz/

## 0. Before recording (~30 s, off-camera)

1. Deploy all three contracts (README → Deploy) and wire the rescuers.
2. Fund the reactive contract with lREACT and each rescuer with a little native gas.
3. Watched wallet holds 1000 tUSD on Base Sepolia and 1000 tUSD on Unichain Sepolia.
4. Watched wallet approved each rescuer (`approve(rescuer, max)`).
5. `arm()` the reactive contract. Inactivity threshold for the demo: 600 s
   (`INACTIVITY_THRESHOLD_SECONDS=600` at deploy time) so the CRON leg is
   demonstrable without waiting 7 days.
6. Have the three explorer tabs open on the contract addresses.

## 1. The setup (0:00–0:40)

- Show the README architecture diagram; say in one sentence: "Terifier watches
  one wallet on two chains, and if something bad happens it moves the money to
  a safe address — no bot."
- Show the watched wallet balance (1000 tUSD per chain) and the safe address
  balance (0).

## 2. The attack (0:40–1:20)

- From the watched wallet, call `approve(ATTACKER, max)` on tUSD (Base Sepolia).
- ATTACKER is not allowlisted, so this is a BAD_APPROVAL trip (reason 1).

## 3. The loop (1:20–2:20)

Show, in order, the three transactions that prove the full loop:

1. **Origin event** — the `approve` transaction on Base Sepolia.
2. **Reactive transaction** — on Lasna, the `Tripped` event (reason 1,
   chain 84532) and the `CallbackRequest` to the Base + Unichain rescuers.
   Point at the `react()` transaction hash on Lasna.
3. **Callback transactions** — on Base Sepolia and Unichain Sepolia, the
   `rescue()` calls from each chain's callback proxy, emitting `Rescued`.

## 4. The result (2:20–2:50)

- Safe address now holds the rescued tUSD on both chains; watched wallet is empty.
- Show `tripped() == true` and `armed() == false` on the reactive contract:
  it fired once and latched.
- (Optional, 10 s) Mention the other two legs without re-running them:
  a bad transfer trips reason 2; 600 s of silence trips reason 3 via CRON.

## 5. Close (2:50–3:00)

- "One wallet, two chains, zero bots. Terifier Sentinel — set it and forget it."
- On-screen: repo URL, track name, deployed addresses.

## Transaction hashes to capture (fill in after the demo run)

| Step | Chain | Tx hash |
| --- | --- | --- |
| Bad approval (origin event) | Base Sepolia | TODO |
| `react()` / `Tripped` | Reactive Lasna | TODO |
| `rescue()` callback | Base Sepolia | TODO |
| `rescue()` callback | Unichain Sepolia | TODO |
