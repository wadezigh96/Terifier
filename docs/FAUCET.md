# Faucet checklist — Terifier Sentinel (Remix deploy)

> Status 2026-11-19: both user wallets have no faucet funds yet.
> Watched: `0x10Ce3Ef4629869697f2C6f408aCA6EE86a5525f7`
> Safe: `0xB4142430B831e047cCF9729148337ad22DF1A9e1`

## Who needs what

| Wallet | Needs |
| --- | --- |
| **Deployer / owner** (the MetaMask account connected in Remix — use the watched wallet as deployer to keep it to one wallet) | Sepolia ETH (to make lREACT) + Base Sepolia ETH + Unichain Sepolia ETH |
| **Watched wallet** (`0x10Ce...`) | A little Base Sepolia ETH + Unichain Sepolia ETH, to pay gas for `approve(rescuer)` on each chain (2 transactions) |
| **Safe address** (`0xB414...`) | **Nothing.** It only receives tokens; it never sends a transaction. Do not waste faucet claims on it. |

Amounts actually needed are small:

- Lasna: 0.05 lREACT to deploy `TerifierReactive` + a top-up for Cron ticks.
  1 Sepolia ETH → 100 lREACT, so one claim is plenty.
- Base Sepolia: ~0.02 ETH total (0.01 to deploy the rescuer + gas, plus the
  watched wallet's `approve`).
- Unichain Sepolia: ~0.02 ETH total (same as Base).

## Order (do Sepolia first — everything else follows from it)

### 1. Ethereum Sepolia ETH — for the deployer/watched wallet

Fresh wallets with no mainnet history are the hard case: most faucets check
for ≥0.001 ETH on Ethereum mainnet at the **same** address.

Try in this order:

1. **Alchemy faucet** — 0.1 Sepolia ETH / 24 h, no Alchemy account needed,
   but requires ≥0.001 ETH on mainnet at that address.
   https://alchemy.com/faucets
2. **Chainlink faucet** — 0.5 Sepolia ETH + 25 test LINK per claim, connect
   MetaMask / WalletConnect. Listed as the largest drip; no mainnet-balance
   requirement is published for it.
3. **Google Cloud Web3 faucet** — 0.05 Sepolia ETH per drip, Google sign-in.
4. **Sepolia PoW faucet (best fallback for a brand-new wallet)** —
   https://sepolia-faucet.pk910.de — no account, no mainnet balance. Your
   browser mines for a while and you claim what you mine. Leave the tab
   open while you do something else.

If Alchemy/QuickNode reject the fresh address, do **not** keep retrying them —
go straight to the PoW faucet. Any site offering to *sell* Sepolia ETH is a
scam; test ETH has no value.

### 2. Make lREACT (Lasna gas)

From the wallet that now holds Sepolia ETH, send **1 Sepolia ETH** to the
Reactive faucet contract:

```
0x9b9BB25f1A81078C544C829c5EB7822d747Cf434
```

→ you receive **100 lREACT**. Max 5 ETH per transaction (500 lREACT);
more is lost. Send the lREACT to the reactive contract after deploying it
(see `docs/REMIX.md` Step 4).

### 3. Base Sepolia ETH — deployer/watched wallet

- **Alchemy Base Sepolia faucet** — 0.1 ETH / 24 h, same mainnet-balance
  check as Sepolia: https://alchemy.com/faucets
- **QuickNode Base Sepolia faucet** —
  https://faucet.quicknode.com/base/sepolia — 1 claim / 12 h, small mainnet
  balance required.
- **No-faucet fallback:** bridge Sepolia ETH to Base Sepolia via the
  official Base bridge (uses the Sepolia ETH from Step 1 as gas + bridged
  amount). This bypasses the Base faucet's mainnet check entirely.

### 4. Unichain Sepolia ETH — deployer/watched wallet

- **Alchemy Unichain Sepolia faucet** — 0.1 ETH / 24 h:
  https://alchemy.com/faucets
- **QuickNode Unichain Sepolia faucet** —
  https://faucet.quicknode.com/unichain/sepolia — 1 claim / 12 h, small
  mainnet balance required.
- **No-faucet fallback:** bridge Sepolia ETH to Unichain Sepolia via the
  official Unichain bridge, same as Base above.

## Checklist (tick off as you claim)

- [ ] Sepolia ETH in deployer/watched wallet (`0x10Ce...`): ≥1 ETH
  (1 ETH → lREACT, rest is spare gas)
- [ ] lREACT received (100 lREACT for 1 Sepolia ETH)
- [ ] Base Sepolia ETH in deployer/watched wallet: ≥0.05 ETH
- [ ] Unichain Sepolia ETH in deployer/watched wallet: ≥0.05 ETH
- [ ] Safe address (`0xB414...`): no faucet needed — skip
- [ ] Ready to deploy: Remix Step 1 (Lasna) in `docs/REMIX.md`

## Verify a claim arrived

Paste the address into the matching explorer and check the balance — do not
trust the faucet page alone:

- Sepolia: https://sepolia.etherscan.io/address/0x10Ce3Ef4629869697f2C6f408aCA6EE86a5525f7
- Base Sepolia: https://sepolia.basescan.org/address/0x10Ce3Ef4629869697f2C6f408aCA6EE86a5525f7
- Unichain Sepolia: https://sepolia.uniscan.xyz/address/0x10Ce3Ef4629869697f2C6f408aCA6EE86a5525f7
- Lasna: https://lasna.reactscan.net/address/0x10Ce3Ef4629869697f2C6f408aCA6EE86a5525f7
