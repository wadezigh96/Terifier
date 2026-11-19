# Terifier Sentinel

**A cross-chain wallet watchdog that moves your tokens to safety — with no bot, no server, no key online.**

Reactive Omni Buildathon (DoraHacks) · Track: **Set It and Forget It**

- Submission window: 5 Nov 2026 19:00 – 6 Dec 2026 03:00 WIB (UTC+7)
- Judging: 7–13 Dec 2026 · Winners: 14 Dec 2026
- Prizes (DoraHacks, per track): 1st $1,000 · 2nd $500 · 3rd $300 · + $100 community prize

> Status: **deployed and verified on-chain, 2026-11-19, armed.**
> `forge test` 18/18 passing. Testnet only; unaudited; never use with real funds.
> Deployed addresses and transaction hashes are in
> [Deployed (live proof)](#deployed-live-proof) below and in
> [docs/DEPLOY_ADDRESSES.md](docs/DEPLOY_ADDRESSES.md).

## What it is

Terifier Sentinel protects **one wallet on two chains at once**. You set a watched
wallet, a safe address, and an allowlist of spenders/recipients you trust. Then you
arm it and forget it:

1. **Bad approval** — your wallet approves a spender that is not allowlisted →
   trip, rescue.
2. **Bad transfer** — your wallet sends tokens to an address that is not
   allowlisted (and is not the safe address) → trip, rescue.
3. **Inactivity (dead-man switch)** — your wallet shows no activity for a
   configurable threshold (default 7 days) → a CRON tick trips, rescue.

On any trip, the reactive contract fires **once** and asks Reactive Network to
callback a rescuer on **every** wired chain. Each rescuer pulls
`min(balance, allowance)` for every registered token (max 16) from the watched
wallet into the safe address. One bad token can never block the rest.

Benign activity (approval/transfer to an allowlisted address, or to the safe
address) just updates the inactivity clock — no trip, no rescue.

```
Base Sepolia (84532) ─┐
  Approval / Transfer │  event
Unichain Sepolia (1301)┘
        │  subscribe
        ▼
TerifierReactive on Reactive Lasna (5318007)
  react() → reason-coded trip (BAD_APPROVAL / BAD_TRANSFER / INACTIVITY)
        │  requestCallbackV_1_0  (payload: rescue(address(0), reason))
        ├───────────────────────► TerifierRescuer on Base Sepolia
        └───────────────────────► TerifierRescuer on Unichain Sepolia
                                    rescue(): transferFrom(watched → safe)
```

## Deployed (live proof)

Deployed and verified on-chain 2026-11-19. All transaction hashes below
returned status 1.

| Contract | Chain | Chain ID | Address |
| --- | --- | --- | --- |
| `TerifierReactive` | Reactive Lasna | 5318007 | `0x298902E4ec5C6C1Fc596C73699F70F02Ee96Fe95` |
| `TerifierRescuer` | Base Sepolia | 84532 | `0xbe9F377e91e1b7a183AC9c344Eb776c4644F9A9F` |
| `TerifierRescuer` | Unichain Sepolia | 1301 | `0xbe9F377e91e1b7a183AC9c344Eb776c4644F9A9F` |
| `MockToken` (tUSD, demo) | Base Sepolia | 84532 | `0x298902E4ec5C6C1Fc596C73699F70F02Ee96Fe95` |
| `MockToken` (tUSD, demo) | Unichain Sepolia | 1301 | `0x298902E4ec5C6C1Fc596C73699F70F02Ee96Fe95` |

The same hex address on three chains is expected, not a mistake: CREATE
addresses depend only on deployer + nonce, and the deployer used nonce 0 for
the first deploy on each chain and nonce 2 for both rescuers.

Key transactions:

| Step | Chain | Tx hash |
| --- | --- | --- |
| lREACT conversion (0.051 Sepolia ETH → 5.355 lREACT) | Sepolia | `0xf5eb0c0dae0619ce86b11d647c5d4a5e38f7cdf821a568dd33cae1700a483820` |
| `TerifierReactive` deploy | Lasna | `0xd4f8dcb4a88236a82b7cc09fe9cab8ff0e78ca0275184ada3d4352359972aecc` |
| `MockToken` deploy + mint 1000 tUSD | Base Sepolia | `0x47a60c7551a91edf68d3182c177600339f889824c6db015577d883f06e7550f9` / `0x1afa76bf4ef012a2e5e7facf35b5c6fa1bffbf17197c736e539374b996863875` |
| `TerifierRescuer` deploy (0.002 ETH) | Base Sepolia | `0xffdc840d7d19f31d20a3dab37dc6828f9e282e94fdde3115359f99cefb657d28` |
| `MockToken` deploy + mint 1000 tUSD | Unichain Sepolia | `0xb16e835b8907b21d7c4bc240350d9c22d699764e554627b38def3308ece25df0` / `0xc01b98146a99df0787ac495ca1691798b23b7bfe37ce874c67e86b18bfa75eb0` |
| `TerifierRescuer` deploy (0.002 ETH) | Unichain Sepolia | `0x652d26fc41b358e3c95f50938d583787a059ff9f5d3c9c3089b566603036552d` |
| `setRescuer(84532)` / `setRescuer(1301)` | Lasna | `0x88c02ae07948d67a8d0a0c53708805801f3fb0966195fd593fbf64cb94af0a4f` / `0xbb71bfd06653bcf2f41795e36ad2a05d5bb675b8fc96b8856ce6a77d884394a0` |
| `addToken` both chains, fund reactive +1 lREACT | Lasna | `0x132e1262d8914b29dd10e1e96bb9726604ff721a16581922c1e0e665bb4f116b`, `0x0d18871dc47446580da82b00b7482eff48b31237c28bc3bc8e4de87eed196cd3`, `0x0e4dace6ba40e4705d18a1fbc4eb0a418fc5e058e4ec2c868b274776315012a6` |
| `approve(rescuer, 1000 tUSD)` both chains | Base / Unichain Sepolia | `0x4d173f8d181633788e7905dbe2be65027d82f695adffe53b308fe149caa45cd8`, `0xab0126a777cd8af72e24599219cd5e55119937ec63c115ea4e15e680cbefe766` |
| `arm()` | Lasna | `0x962887aaef2fb38d01f7b80db6b0eaea2b0c4758dd88c06aa906614f6cd6b2e6` |

Verified state after deploy: `armed() == true`, `tripped() == false`,
`inactivityThreshold() == 600`, reactive balance ≈ 1.005 lREACT, both
rescuers hold 0.002 ETH, watched wallet holds 1000 tUSD on each chain with
1000 tUSD allowance to its rescuer. Full proof in
[docs/DEPLOY_ADDRESSES.md](docs/DEPLOY_ADDRESSES.md) and the deploy logs
(`deploy_*.log`). The live-attack full loop (bad approval → `Tripped` →
callbacks) is the demo in [docs/VIDEO_SCRIPT.md](docs/VIDEO_SCRIPT.md);
its tx hashes are recorded there once the attack is run.

## Chains (testnet only — mainnet and testnet must not be mixed)

| Role | Chain | Chain ID | Callback proxy / system |
| --- | --- | --- | --- |
| Reactive contract | Reactive Lasna | 5318007 | System `0x8888888888888888888888888888888888888888` |
| Origin + destination | Base Sepolia | 84532 | Proxy `0x476F44b11F5C942c58f4c8E3d0300E5710743585` |
| Origin + destination | Unichain Sepolia | 1301 | Proxy `0x775c9B990ADe401060B78D0e98684eEf8d2466C1` |

RPCs: Lasna `https://lasna-rpc.rnk.dev/`, Base Sepolia `https://sepolia.base.org`,
Unichain Sepolia `https://sepolia.unichain.org`.

## How Terifier differs from Tripwire

Tripwire (`bars26/tripwire`) is an earlier entry in the same track. Terifier is a
new, independent implementation — not a fork — and differs in every behaviour
that matters:

| | Tripwire | Terifier Sentinel |
| --- | --- | --- |
| Trip reasons | Approval/Transfer to non-allowlist only | **Reason-coded trips: BAD_APPROVAL (1), BAD_TRANSFER (2), INACTIVITY (3)** — the reason travels in the `Tripped` event and the rescue callback payload |
| Dead-man switch | None | **CRON-based inactivity trip** (Cron100, ~2 min ticks; owner-settable threshold, default 7 days). Benign activity resets the clock |
| Arm / disarm / reset | Not present | **arm() / disarm() / resetTrip()** (owner-only) + trip-once latch: a second bad event cannot re-trip; `react()` falls through instead of reverting when disarmed or already tripped |
| Allowlist scope | Spenders (approvals) | **Spenders AND recipients** (approvals and transfers) |
| Rescue limits | All tokens, full allowance | **Per-token cap: max 16 tokens per rescuer; rescue = min(balance, allowance); per-token try/catch with `Rescued` / `RescueSkipped` events** so one broken token cannot block the rest |
| Multi-chain | One reactive → rescuers per chain | **One reactive contract watches Base Sepolia + Unichain Sepolia and callbacks both rescuers on a single trip** |

## Contracts

| Contract | File | Chain |
| --- | --- | --- |
| `TerifierReactive` | `src/TerifierReactive.sol` | Reactive Lasna |
| `TerifierRescuer` | `src/TerifierRescuer.sol` | Base Sepolia + Unichain Sepolia (one each) |
| `MockToken` | `src/MockToken.sol` | Demo/test ERC-20 (mintable by anyone — demo only) |

Built on the official Reactive Omni library
[`Reactive-Network/reactive-lib-omni` v0.1.0](https://github.com/Reactive-Network/reactive-lib-omni)
(`AbstractReactive`, `AbstractCallback`, `ISystemContract`, `IReactive`, `IPayable`),
Solidity 0.8.29, Foundry 1.9.0. Note: the older repo name
`reactive-smart-contracts` does not exist; the current Omni library is
`reactive-lib-omni` (imports via `@reactive/src/...`).

Key API facts (from [dev.reactive.network](https://dev.reactive.network/)):
- `SYSTEM = 0x8888888888888888888888888888888888888888`; `react(LogRecord)` is `onlySystem`.
- Subscriptions: `SYSTEM.subscribe(chainId, contract, topic0, topic1, topic2, topic3)`.
- Callbacks: `SYSTEM.requestCallbackV_1_0(CallbackConfiguration_V_1_0{chainId, recipient, gasLimit, payload})`;
  the first payload argument must be `address(0)` — the proxy overwrites it with the reactive address.
- Callback methods are guarded by `onlyServiceProvider` + `onlyCallbackSender(reactive_)`.
- CRON: legacy system `0x0000000000000000000000000000000000fffFfF` emits `Cron100`
  (topic `0xb49937fb…1503c70`, ~2 min). Cron ticks bill on every tick whether or not
  `react()` does anything, so production should use `Cron1000` (~17 min) or longer;
  `Cron100` is used here deliberately so the dead-man demo fires quickly.
- Deploy order: reactive first → callback with the reactive address → set the
  recipient on the reactive contract via an owner setter → fund both.

## Setup

```bash
git clone https://github.com/wadezigh96/Terifier.git
cd Terifier
cp .env.example .env   # fill in WATCHED_WALLET, SAFE_ADDRESS, PRIVATE_KEY (testnet only)
export PATH="$HOME/.foundry/bin:$PATH"
forge build
forge test   # 18/18 passing
```

## Deploy (testnet)

**Prefer Remix?** See [docs/REMIX.md](docs/REMIX.md) — same contracts, Remix-ready
copies in `remix/` (imports point at the pinned `reactive-lib-omni` commit on
GitHub), deployed from your browser with MetaMask. Your private key never
leaves your machine.

Four steps with Foundry, one chain per run — see `script/Deploy.s.sol` and `.env.example`:

```bash
# 1. Reactive contract on Lasna (rescuers may be address(0) for now)
TARGET=lasna forge script script/Deploy.s.sol --rpc-url $LASNA_RPC_URL --broadcast
# 2. Rescuer + demo token on Base Sepolia (deploys MockToken tUSD, mints 1000 to watched)
TARGET=base forge script script/Deploy.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast
# 3. Rescuer + demo token on Unichain Sepolia
TARGET=unichain forge script script/Deploy.s.sol --rpc-url $UNICHAIN_SEPOLIA_RPC_URL --broadcast
# 4. Wire both rescuers into the reactive contract
TARGET=wire forge script script/Deploy.s.sol --rpc-url $LASNA_RPC_URL --broadcast
```

Then fund and arm (all testnet, no real funds):

1. **lREACT for the reactive contract** (pays for `react()` + callback requests):
   send Sepolia ETH to the faucet contract `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`
   — 1 ETH → 100 lREACT, max 5 ETH per transaction (500 lREACT; more is lost).
   Then send lREACT to the reactive contract address (its `receive()` is payable).
   A Base Sepolia faucet also exists: `0x2afaFD298b23b62760711756088F75B7409f5967`.
2. **Native gas for each rescuer** (callbacks are billed to the rescuer in the
   destination chain's native token): send a little Base Sepolia ETH / Unichain
   Sepolia ETH to each rescuer address.
3. **Watched wallet approves each rescuer** for each token it should be able to
   pull: `token.approve(rescuer, amount)` on each destination chain.
4. **Arm it:** `cast send <REACTIVE> "arm()" --rpc-url $LASNA_RPC_URL --private-key $PRIVATE_KEY`.
   (Deploy starts disarmed on purpose — wire and fund first, then arm.)

Verify on Sourcify after deploy:
`forge verify-contract --verifier sourcify --chain-id 5318007 <ADDR> TerifierReactive`
(and the rescuers with their chain IDs).

## Demo

Full under-3-minute script: [docs/DEMO.md](docs/DEMO.md).
In short: fund the watched wallet → approve the rescuer → arm → trigger a bad
approval from the watched wallet → show the `Tripped` event on Lasna, the
callback transaction on Base/Unichain Sepolia, and the rescued balances in the
safe address.

## Security notes

- **ERC-20 only.** Native ETH in an EOA cannot be pulled by a contract — a
  rescue only moves tokens the watched wallet pre-approved to the rescuer.
- **Pre-approval is the trust boundary.** The rescuer can only pull up to the
  allowance the owner granted. Set allowances deliberately; revoke them when
  you disarm.
- **Trip-once latch.** After a trip the contract disarms itself. A second bad
  event cannot trigger a second rescue until the owner calls `resetTrip()` and
  `arm()` again — this bounds the damage a flapping event source can do, but it
  also means you must re-arm after a genuine trip.
- **CRON billing.** Every Cron100 tick (~2 min) bills the reactive contract
  whether or not it trips. Keep the contract funded, or switch to `Cron1000`.
- **Debt stops everything.** A reactive contract in debt receives no events and
  a callback contract in debt receives no callbacks. `coverDebt()` (owner-only)
  settles from the contract's own balance.
- **Testnet only, unaudited.** Do not point this at a wallet holding real value.

## Submission checklist

See [docs/SUBMISSION.md](docs/SUBMISSION.md): title, description, public repo,
deployed addresses (done, see above), transaction hashes for the full origin → callback
loop (demo tx hashes still to be recorded after the live attack is run),
demo video (script in [docs/VIDEO_SCRIPT.md](docs/VIDEO_SCRIPT.md), < 3 min),
one track only.

## License

MIT — see [LICENSE](LICENSE).
