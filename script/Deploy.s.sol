// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Script, console } from "forge-std/Script.sol";
import { IPayable } from "@reactive/src/interfaces/IPayable.sol";
import { TerifierReactive } from "../src/TerifierReactive.sol";
import { TerifierRescuer } from "../src/TerifierRescuer.sol";
import { MockToken } from "../src/MockToken.sol";

/// @title Terifier Sentinel deploy script (testnet only).
/// @notice One script, one chain per run — each step targets a different RPC,
///         so run it four times. Deployment order (callback sender is
///         immutable, the cycle breaks on the reactive side):
///           1. TARGET=lasna    deploy TerifierReactive on Reactive Lasna.
///              Rescuers may be address(0) at this point.
///           2. TARGET=base     deploy MockToken + TerifierRescuer on Base Sepolia.
///           3. TARGET=unichain deploy MockToken + TerifierRescuer on Unichain Sepolia.
///           4. TARGET=wire     set both rescuers on the reactive contract.
///         Then fund both sides (see README) and call arm() on the reactive
///         contract. No broadcast happens unless --broadcast is passed.
/// @dev Required env per step is documented in .env.example. This script never
///      prints the private key. Replace the placeholder key before use.
contract Deploy is Script {
    uint256 internal constant BASE_SEPOLIA = 84532;
    uint256 internal constant UNICHAIN_SEPOLIA = 1301;

    address internal constant BASE_SEPOLIA_PROXY = 0x476F44b11F5C942c58f4c8E3d0300E5710743585;
    address internal constant UNICHAIN_SEPOLIA_PROXY = 0x775c9B990ADe401060B78D0e98684eEf8d2466C1;

    function run() external {
        string memory target = vm.envString("TARGET");
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address watched = vm.envAddress("WATCHED_WALLET");
        address safe = vm.envAddress("SAFE_ADDRESS");

        if (keccak256(bytes(target)) == keccak256(bytes("lasna"))) {
            _deployReactive(pk, watched, safe);
        } else if (keccak256(bytes(target)) == keccak256(bytes("base"))) {
            _deployRescuer(pk, watched, safe, BASE_SEPOLIA, BASE_SEPOLIA_PROXY, "BASE_TOKEN_ADDRESS");
        } else if (keccak256(bytes(target)) == keccak256(bytes("unichain"))) {
            _deployRescuer(pk, watched, safe, UNICHAIN_SEPOLIA, UNICHAIN_SEPOLIA_PROXY, "UNICHAIN_TOKEN_ADDRESS");
        } else if (keccak256(bytes(target)) == keccak256(bytes("wire"))) {
            _wire(pk);
        } else {
            revert("Deploy: TARGET must be lasna | base | unichain | wire");
        }
    }

    function _deployReactive(uint256 pk, address watched, address safe) internal {
        uint256 threshold = vm.envOr("INACTIVITY_THRESHOLD_SECONDS", uint256(7 days));
        address baseToken = vm.envOr("BASE_TOKEN_ADDRESS", address(0));
        address uniToken = vm.envOr("UNICHAIN_TOKEN_ADDRESS", address(0));
        address baseRescuer = vm.envOr("BASE_RESCUER_ADDRESS", address(0));
        address uniRescuer = vm.envOr("UNICHAIN_RESCUER_ADDRESS", address(0));

        address[] memory baseTokens = new address[](baseToken == address(0) ? 0 : 1);
        if (baseToken != address(0)) baseTokens[0] = baseToken;
        address[] memory uniTokens = new address[](uniToken == address(0) ? 0 : 1);
        if (uniToken != address(0)) uniTokens[0] = uniToken;

        vm.startBroadcast(pk);
        TerifierReactive reactive = new TerifierReactive{ value: 0.05 ether }(
            watched, safe, threshold, baseTokens, uniTokens, baseRescuer, uniRescuer
        );
        vm.stopBroadcast();

        console.log("TerifierReactive (Lasna):", address(reactive));
        console.log("  watched:", watched);
        console.log("  safe:", safe);
        console.log("  inactivityThreshold (s):", threshold);
        console.log("  NEXT: set REACTIVE_ADDRESS in .env, then deploy rescuers.");
    }

    function _deployRescuer(
        uint256 pk,
        address watched,
        address safe,
        uint256 chainId,
        address proxy,
        string memory tokenEnv
    ) internal {
        address reactive = vm.envAddress("REACTIVE_ADDRESS");
        address token = vm.envOr(tokenEnv, address(0));

        vm.startBroadcast(pk);
        if (token == address(0)) {
            MockToken demo = new MockToken("Terifier Demo USD", "tUSD");
            token = address(demo);
            demo.mint(watched, 1000 ether);
            console.log("MockToken (tUSD):", token, "(1000 tUSD minted to watched wallet)");
        }
        address[] memory tokens = new address[](1);
        tokens[0] = token;
        // Rescuer value: 0.002 ETH by default (override with RESCUER_VALUE in
        // wei). 0.01 ETH was the original default, but the Base Sepolia
        // deployer only holds 0.0101 ETH, which cannot cover 0.01 value +
        // deploy gas for MockToken + rescuer. 0.002 still funds callbacks.
        uint256 rescuerValue = vm.envOr("RESCUER_VALUE", uint256(0.002 ether));
        TerifierRescuer rescuer = new TerifierRescuer{ value: rescuerValue }(
            IPayable(payable(proxy)), reactive, watched, safe, tokens
        );
        vm.stopBroadcast();

        console.log("TerifierRescuer (chainId):", chainId, address(rescuer));
        console.log("  callback proxy:", proxy);
        console.log("  callback sender (reactive):", reactive);
        console.log("  NEXT: set the matching _RESCUER_ADDRESS in .env, fund the rescuer,");
        console.log("  and have the watched wallet approve the rescuer for each token.");
    }

    function _wire(uint256 pk) internal {
        address reactiveAddr = vm.envAddress("REACTIVE_ADDRESS");
        address baseRescuer = vm.envAddress("BASE_RESCUER_ADDRESS");
        address uniRescuer = vm.envAddress("UNICHAIN_RESCUER_ADDRESS");

        vm.startBroadcast(pk);
        TerifierReactive reactive = TerifierReactive(payable(reactiveAddr));
        reactive.setRescuer(BASE_SEPOLIA, baseRescuer);
        reactive.setRescuer(UNICHAIN_SEPOLIA, uniRescuer);
        vm.stopBroadcast();

        console.log("Wired rescuers on reactive:", reactiveAddr);
        console.log("  Base Sepolia rescuer:", baseRescuer);
        console.log("  Unichain Sepolia rescuer:", uniRescuer);
        console.log("  NEXT: fund reactive + rescuers, then call arm() on the reactive contract.");
    }
}
