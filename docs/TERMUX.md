# Deploy Terifier Sentinel via Termux (Android)

Yes, it works — but **only inside an Ubuntu container in Termux**, not in
Termux directly. Foundry's `forge`/`cast` binaries are built for glibc Linux;
Termux itself runs on Android's Bionic libc, so the binaries will not run
there. The proven pattern (used for Foundry on tablets/phones) is:

Termux → `proot-distro` → Ubuntu → Foundry → `forge script`

> Testnet only, fresh wallet only. Keep the phone awake during deploys
> (Android kills background Termux sessions) and never paste the private key
> anywhere except the `.env` file inside your own Termux.

## 0. Prerequisites

- Android 7+, **ARM64** phone (`aarch64` — check with `uname -m` in Termux;
  32-bit ARM will not run Foundry releases).
- ~2 GB free storage, stable internet.
- **Termux from F-Droid, not the Play Store** — the Play Store build is
  outdated and package installs frequently fail.
- The Terifier repo pushed to GitHub first (`wadezigh96/Terifier`) — Termux
  will `git clone` it. Right now the GitHub repo is still empty; the code
  lives in `~/workspace/terifier/` until it is pushed.

## 1. Termux setup

```bash
pkg update && pkg upgrade
pkg install proot-distro git
proot-distro install ubuntu
proot-distro login ubuntu
```

You are now inside Ubuntu (the prompt changes). Everything below runs
**inside** that Ubuntu login, not in plain Termux.

## 2. Foundry inside Ubuntu

```bash
apt update && apt install -y curl git build-essential
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc
foundryup
export PATH="$HOME/.foundry/bin:$PATH"
forge --version   # expect Foundry 1.9.x
cast --version
```

If `foundryup` is slow, wait — it downloads `forge`, `cast`, `anvil`,
`chisel` for `aarch64` Linux. Keep Termux in the foreground; run
`termux-wake-lock` in a second Termux session first if your phone sleeps.

## 3. Get the Terifier code

```bash
git clone https://github.com/wadezigh96/Terifier.git
cd Terifier
cp .env.example .env
chmod 600 .env
```

Fill in `.env` with `nano .env` (or your editor):

```
WATCHED_WALLET=0x10Ce3Ef4629869697f2C6f408aCA6EE86a5525f7
SAFE_ADDRESS=0xB4142430B831e047cCF9729148337ad22DF1A9e1
INACTIVITY_THRESHOLD_SECONDS=600
PRIVATE_KEY=0x...   # testnet-only deployer key — never commit, never share
```

Then verify the build exactly as on a laptop:

```bash
forge build
forge test   # expect 18/18 passing
```

## 4. Deploy — same four steps as the README

One chain per run, same as `docs/REMIX.md` / `README.md`:

```bash
export LASNA_RPC_URL=https://lasna-rpc.rnk.dev/
export BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
export UNICHAIN_SEPOLIA_RPC_URL=https://sepolia.unichain.org

TARGET=lasna    forge script script/Deploy.s.sol --rpc-url $LASNA_RPC_URL --broadcast
TARGET=base     forge script script/Deploy.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast
TARGET=unichain forge script script/Deploy.s.sol --rpc-url $UNICHAIN_SEPOLIA_RPC_URL --broadcast
TARGET=wire     forge script script/Deploy.s.sol --rpc-url $LASNA_RPC_URL --broadcast
```

After each step, copy the printed address into `.env`
(`REACTIVE_ADDRESS`, `BASE_RESCUER_ADDRESS`, `UNICHAIN_RESCUER_ADDRESS`,
token addresses) before the next step. Then fund, approve, and arm exactly
as in the README:

```bash
# fund lREACT / native gas first (see README), then:
cast send <REACTIVE_ADDRESS> "arm()" \
  --rpc-url $LASNA_RPC_URL --private-key $PRIVATE_KEY
```

Record every deployed address and tx hash in `docs/SUBMISSION.md`.

## 5. If Foundry will not run in Termux

Fallbacks, in order of ease on a phone:

1. **Remix in the phone browser (easiest).** Open
   https://remix.ethereum.org in Chrome on the phone, upload the files in
   `remix/`, connect MetaMask (mobile app, Injected Provider), and follow
   `docs/REMIX.md`. No terminal, no install, key stays in MetaMask.
2. **Node.js in plain Termux (no proot).** `pkg install nodejs git`, then a
   small `ethers.js` deploy script using the compiled ABI/bytecode from
   `out/` — this avoids Foundry entirely, but you would need a deploy script
   written for it (not included in this repo; the Foundry script is the
   tested path).
3. **Borrow a laptop / cloud VM for the 10-minute deploy**, then do the
   demo and submission from the phone.

## Troubleshooting (Termux-specific)

- `forge: command not found` — you are in plain Termux, not in
  `proot-distro login ubuntu`, or `~/.foundry/bin` is not on `PATH` in that
  shell. Re-run the `export PATH=...` line.
- `Exec format error` / binary will not start — wrong architecture
  (`uname -m` is not `aarch64`) or you tried to run the glibc binary
  directly in Termux without Ubuntu.
- Session dies mid-deploy — Android killed Termux in the background. Run
  `termux-wake-lock`, keep the screen on, and re-run the failed step only
  (each `TARGET` step is idempotent except re-deploying creates a new
  contract — reuse the printed address instead of re-running a step that
  already succeeded).
- `proot-distro install ubuntu` is slow — it downloads ~40 MB rootfs plus
  Ubuntu packages; use Wi-Fi.
