# Deploy Terifier Sentinel via Remix (no private key leaves your browser)

This is the safest deploy route: your key stays in MetaMask, never in chat,
never in a `.env` on anyone else's machine. Remix runs in your browser at
https://remix.ethereum.org.

> Testnet only. Use a fresh wallet with faucet funds only.

## 0. Files

Upload these three files to Remix (File Explorer → Upload, or drag-and-drop):

- `remix/TerifierReactive.sol`
- `remix/TerifierRescuer.sol`
- `remix/MockToken.sol`

These are the same contracts as `src/`, except the `@reactive/...` imports are
rewritten to pinned GitHub URLs for
`Reactive-Network/reactive-lib-omni` v0.1.0
(commit `3ade0dcf1d27e67e5783ef807e73a1b9e0c0cce8`), which Remix can fetch.
Compiler: Solidity **0.8.29**, optimizer on, 200 runs.
If Remix warns about an import, check that you uploaded the files exactly as
named — do not rename them.

## 1. Add the three testnet networks to MetaMask

| Network | Chain ID | RPC | Currency | Explorer |
| --- | --- | --- | --- | --- |
| Reactive Lasna | 5318007 | https://lasna-rpc.rnk.dev/ | REACT | https://lasna.reactscan.net/ |
| Base Sepolia | 84532 | https://sepolia.base.org | ETH | https://sepolia.basescan.org/ |
| Unichain Sepolia | 1301 | https://sepolia.unichain.org | ETH | https://sepolia.uniscan.xyz/ |

In Remix, use **Injected Provider – MetaMask** as the environment, and switch
MetaMask to the matching network before each deploy step below.

## 2. Get faucet funds (fresh wallet only)

- **Sepolia ETH** (from any Sepolia faucet) → send 1 ETH to the lREACT faucet
  contract `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434` to receive 100 lREACT
  (max 5 ETH per transaction; more is lost). This pays for the reactive
  contract on Lasna.
- **Base Sepolia ETH** and **Unichain Sepolia ETH** (chain faucets) for the two
  rescuer deploys and their callback gas.

## 3. Deploy — in this exact order

The rescuer needs the reactive address at construction, and the reactive
contract needs the rescuer addresses afterwards via `setRescuer`. So:

### Step 1 — TerifierReactive on Lasna (network: Reactive Lasna)

Contract: `TerifierReactive`. It is `payable` — set Remix **Value to 0.05**
(0.05 lREACT) before deploying.

Constructor args:

```
watchedWallet_:     0x...  (wallet Terifier protects)
safeAddress_:       0x...  (rescue destination)
inactivityThreshold_: 600  (demo: 600 seconds; production default is 604800 = 7 days)
baseTokens_:        []     (empty for now — token addresses are added after Step 2/3, or pass the MockToken address if already deployed)
unichainTokens_:    []
baseRescuer_:       0x0000000000000000000000000000000000000000
unichainRescuer_:   0x0000000000000000000000000000000000000000
```

Save the deployed address as `REACTIVE_ADDRESS`.

### Step 2 — MockToken + TerifierRescuer on Base Sepolia

Switch MetaMask to **Base Sepolia**.

1. Deploy `MockToken` with `("Terifier Demo USD", "tUSD")`, then call
   `mint(watchedWallet, 1000000000000000000000)` (1000 tUSD, 18 decimals).
   Save the token address.
2. Deploy `TerifierRescuer` (payable — Value **0.01** ETH):

```
callbackProxy_:  0x476F44b11F5C942c58f4c8E3d0300E5710743585  (Base Sepolia proxy)
callbackSender_: <REACTIVE_ADDRESS from Step 1>
watchedWallet_:  <same watched wallet>
safeAddress_:    <same safe address>
tokens_:         [<MockToken address>]
```

Save the deployed address as `BASE_RESCUER_ADDRESS`.

### Step 3 — MockToken + TerifierRescuer on Unichain Sepolia

Same as Step 2, on **Unichain Sepolia**, with proxy
`0x775c9B990ADe401060B78D0e98684eEf8d2466C1`. Save the token address and
`UNICHAIN_RESCUER_ADDRESS`.

### Step 4 — Wire the rescuers into the reactive contract (Lasna)

Switch MetaMask back to **Reactive Lasna**. Open the deployed
`TerifierReactive` in Remix (same contract, "At Address" with
`REACTIVE_ADDRESS`) and call, as the deployer/owner:

1. `setRescuer(84532, <BASE_RESCUER_ADDRESS>)`
2. `setRescuer(1301, <UNICHAIN_RESCUER_ADDRESS>)`
3. `addToken(84532, <Base MockToken>)` and `addToken(1301, <Unichain MockToken>)`
   — this also creates the Approval/Transfer subscriptions for those tokens.

## 4. Fund and arm

1. Send lREACT to the reactive contract address (it has a payable `receive()`).
   Keep it funded — every Cron100 tick (~2 min) bills it whether or not it trips.
2. Send a little Base Sepolia ETH to the Base rescuer and Unichain Sepolia ETH
   to the Unichain rescuer (callbacks are billed to the rescuer in native gas).
3. From the **watched wallet**, on each chain, call the MockToken's
   `approve(<rescuer on that chain>, 1000000000000000000000)` (1000 tUSD).
   Without this approval the rescuer cannot pull anything.
4. On Lasna, call `arm()` on the reactive contract (owner only). The contract
   starts **disarmed** on purpose — wire and fund first, then arm.

## 5. Record the submission evidence

Copy every deployed address and transaction hash into
`docs/SUBMISSION.md` (placeholders are marked TODO there):

- `TerifierReactive` (Lasna) address + deploy tx
- `TerifierRescuer` (Base Sepolia) + `MockToken` (Base) addresses + deploy txs
- `TerifierRescuer` (Unichain Sepolia) + `MockToken` (Unichain) addresses + deploy txs
- The `Tripped` transaction on Lasna and the callback/rescue transactions on
  Base + Unichain Sepolia from the demo (see `docs/DEMO.md`)

Verify each contract on Sourcify after deploy:
`forge verify-contract --verifier sourcify --chain-id <id> <address> <ContractName>`.

## Troubleshooting

- **Remix cannot resolve an import:** you uploaded a `src/` file instead of
  the `remix/` copy. The `src/` files use Foundry remappings (`@reactive/...`)
  that Remix does not understand.
- **Deploy reverts with `ZeroAddress`:** a constructor address is still
  `0x0000...0000` — check `watchedWallet` / `safeAddress`.
- **Rescue moves nothing:** the watched wallet has not `approve()`d the
  rescuer for that token on that chain, or the allowance is below the balance.
- **No events reach the reactive contract:** the contract is disarmed, in debt
  (fund it, then `coverDebt()`), or the token was never added via `addToken()`.
