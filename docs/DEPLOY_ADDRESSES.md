# Terifier Sentinel — Deploy addresses (filled 2026-11-19)

> Assumption: the user sent the addresses in the order requested —
> first = watched wallet, second = safe address. **Confirm this before
> deploying. If they are swapped, swap them below; a swapped deploy would
> rescue the wrong wallet's tokens to the wrong place.**
>
> Balances re-checked 2026-11-19 ~18:58 WIB: Sepolia 0.0801 ETH, Base
> Sepolia 0.0101 ETH, Unichain Sepolia 0.075 ETH, Lasna 0 lREACT.
> Enough to deploy ONLY with two adjustments: (1) convert 0.05 Sepolia ETH
> to 5 lREACT first; (2) deploy the Base rescuer with Value 0.002 ETH
> (not 0.01 ETH) — 0.0101 ETH cannot cover both a 0.01 value and gas.
>
> Both addresses were validated 2026-11-19: 42 chars, valid hex,
> EIP-55 checksum matches `cast --to-checksum-address` output.

## Addresses

| Role | Address |
| --- | --- |
| Watched wallet | `0x10Ce3Ef4629869697f2C6f408aCA6EE86a5525f7` |
| Safe address | `0xB4142430B831e047cCF9729148337ad22DF1A9e1` |

## Remix — exact constructor args

### Step 1 — TerifierReactive on Lasna (value: 0.05 lREACT)

```
watchedWallet_:     0x10Ce3Ef4629869697f2C6f408aCA6EE86a5525f7
safeAddress_:       0xB4142430B831e047cCF9729148337ad22DF1A9e1
inactivityThreshold_: 600
baseTokens_:        []
unichainTokens_:    []
baseRescuer_:       0x0000000000000000000000000000000000000000
unichainRescuer_:   0x0000000000000000000000000000000000000000
```

Record the deployed address as `REACTIVE_ADDRESS`.

### Step 2 — Base Sepolia (MockToken + TerifierRescuer, value: 0.01 ETH)

MockToken: `("Terifier Demo USD", "tUSD")`, then
`mint(0x10Ce3Ef4629869697f2C6f408aCA6EE86a5525f7, 1000000000000000000000)`.

TerifierRescuer:

```
callbackProxy_:  0x476F44b11F5C942c58f4c8E3d0300E5710743585
callbackSender_: <REACTIVE_ADDRESS>
watchedWallet_:  0x10Ce3Ef4629869697f2C6f408aCA6EE86a5525f7
safeAddress_:    0xB4142430B831e047cCF9729148337ad22DF1A9e1
tokens_:         [<Base MockToken address>]
```

Record as `BASE_RESCUER_ADDRESS` (+ Base token address).

### Step 3 — Unichain Sepolia (same, proxy differs)

```
callbackProxy_:  0x775c9B990ADe401060B78D0e98684eEf8d2466C1
callbackSender_: <REACTIVE_ADDRESS>
watchedWallet_:  0x10Ce3Ef4629869697f2C6f408aCA6EE86a5525f7
safeAddress_:    0xB4142430B831e047cCF9729148337ad22DF1A9e1
tokens_:         [<Unichain MockToken address>]
```

Record as `UNICHAIN_RESCUER_ADDRESS` (+ Unichain token address).

### Step 4 — Wire on Lasna (as deployer/owner)

```
setRescuer(84532, <BASE_RESCUER_ADDRESS>)
setRescuer(1301, <UNICHAIN_RESCUER_ADDRESS>)
addToken(84532, <Base MockToken>)
addToken(1301, <Unichain MockToken>)
```

Then fund (lREACT to reactive, native ETH to each rescuer), have the watched
wallet `approve()` each rescuer for 1000 tUSD on its chain, and call `arm()`.

## Foundry .env values (same addresses)

```
WATCHED_WALLET=0x10Ce3Ef4629869697f2C6f408aCA6EE86a5525f7
SAFE_ADDRESS=0xB4142430B831e047cCF9729148337ad22DF1A9e1
INACTIVITY_THRESHOLD_SECONDS=600
```

## Deployed — verified on-chain 2026-11-19 (armed, threshold 600s)

| Contract | Chain | Chain ID | Address |
| --- | --- | --- | --- |
| TerifierReactive | Reactive Lasna | 5318007 | `0x298902E4ec5C6C1Fc596C73699F70F02Ee96Fe95` |
| TerifierRescuer | Base Sepolia | 84532 | `0xbe9F377e91e1b7a183AC9c344Eb776c4644F9A9F` |
| TerifierRescuer | Unichain Sepolia | 1301 | `0xbe9F377e91e1b7a183AC9c344Eb776c4644F9A9F` |
| MockToken (tUSD, demo) | Base Sepolia | 84532 | `0x298902E4ec5C6C1Fc596C73699F70F02Ee96Fe95` |
| MockToken (tUSD, demo) | Unichain Sepolia | 1301 | `0x298902E4ec5C6C1Fc596C73699F70F02Ee96Fe95` |

Note: the same hex address appears on three chains — that is expected, not a
mistake. CREATE addresses depend only on deployer + nonce, and the deployer
used nonce 0 for the first deploy on each chain (reactive on Lasna, MockToken
on Base/Unichain) and nonce 2 for both rescuers.

Deploy tx hashes (all status 1, verified on-chain):

| Step | Chain | Tx hash |
| --- | --- | --- |
| TerifierReactive deploy | Lasna | `0xd4f8dcb4a88236a82b7cc09fe9cab8ff0e78ca0275184ada3d4352359972aecc` |
| MockToken deploy | Base Sepolia | `0x47a60c7551a91edf68d3182c177600339f889824c6db015577d883f06e7550f9` |
| MockToken mint 1000 tUSD | Base Sepolia | `0x1afa76bf4ef012a2e5e7facf35b5c6fa1bffbf17197c736e539374b996863875` |
| TerifierRescuer deploy (0.002 ETH) | Base Sepolia | `0xffdc840d7d19f31d20a3dab37dc6828f9e282e94fdde3115359f99cefb657d28` |
| MockToken deploy | Unichain Sepolia | `0xb16e835b8907b21d7c4bc240350d9c22d699764e554627b38def3308ece25df0` |
| MockToken mint 1000 tUSD | Unichain Sepolia | `0xc01b98146a99df0787ac495ca1691798b23b7bfe37ce874c67e86b18bfa75eb0` |
| TerifierRescuer deploy (0.002 ETH) | Unichain Sepolia | `0x652d26fc41b358e3c95f50938d583787a059ff9f5d3c9c3089b566603036552d` |
| `setRescuer(84532, …)` | Lasna | `0x88c02ae07948d67a8d0a0c53708805801f3fb0966195fd593fbf64cb94af0a4f` |
| `setRescuer(1301, …)` | Lasna | `0xbb71bfd06653bcf2f41795e36ad2a05d5bb675b8fc96b8856ce6a77d884394a0` |
| `addToken(84532, tUSD)` | Lasna | `0x132e1262d8914b29dd10e1e96bb9726604ff721a16581922c1e0e665bb4f116b` |
| `addToken(1301, tUSD)` | Lasna | `0x0d18871dc47446580da82b00b7482eff48b31237c28bc3bc8e4de87eed196cd3` |
| Fund reactive +1 lREACT | Lasna | `0x0e4dace6ba40e4705d18a1fbc4eb0a418fc5e058e4ec2c868b274776315012a6` |
| `approve(rescuer, 1000 tUSD)` | Base Sepolia | `0x4d173f8d181633788e7905dbe2be65027d82f695adffe53b308fe149caa45cd8` |
| `approve(rescuer, 1000 tUSD)` | Unichain Sepolia | `0xab0126a777cd8af72e24599219cd5e55119937ec63c115ea4e15e680cbefe766` |
| `arm()` | Lasna | `0x962887aaef2fb38d01f7b80db6b0eaea2b0c4758dd88c06aa906614f6cd6b2e6` |

Verified state after deploy: `armed = true`, `tripped = false`,
`inactivityThreshold = 600`, reactive balance ≈ 1.005 lREACT, both rescuers
hold 0.002 ETH, watched wallet holds 1000 tUSD on each chain with 1000 tUSD
allowance to its rescuer. lREACT conversion tx (Sepolia):
`0xf5eb0c0dae0619ce86b11d647c5d4a5e38f7cdf821a568dd33cae1700a483820`
(0.051 ETH → 5.355 lREACT).

## Still TODO (fill after demo)

- Demo video (< 3 min) + full-loop tx hashes: bad approval origin tx,
  Lasna `Tripped` tx, callback/rescue txs on Base + Unichain.
