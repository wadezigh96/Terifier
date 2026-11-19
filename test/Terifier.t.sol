// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import { Test } from "forge-std/Test.sol";
import { IPayable } from "@reactive/src/interfaces/IPayable.sol";
import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { TerifierReactive } from "../src/TerifierReactive.sol";
import { TerifierRescuer } from "../src/TerifierRescuer.sol";
import { MockToken } from "../src/MockToken.sol";

/// @notice Unit tests for Terifier Sentinel.
/// @dev The Reactive system contract (0x8888...8888) has no code in tests, so
///      SYSTEM.subscribe / requestCallbackV_1_0 are no-ops here. react() is
///      driven directly via vm.prank(SYSTEM) to satisfy onlySystem, and
///      rescue() via vm.prank(proxy) to satisfy onlyServiceProvider.
contract TerifierTest is Test {
    address internal constant SYSTEM = 0x8888888888888888888888888888888888888888;
    address internal constant LEGACY_SYSTEM = 0x0000000000000000000000000000000000fffFfF;
    uint256 internal constant BASE = 84532;
    uint256 internal constant UNI = 1301;
    uint256 internal constant THRESHOLD = 7 days;
    uint256 internal constant T0 = 1_000_000;

    TerifierReactive internal reactive;
    TerifierRescuer internal rescuer;
    MockToken internal tokenBase;
    MockToken internal tokenUni;
    MockToken internal tokenNoAllowance;

    address internal watched = makeAddr("watched");
    address internal safe = makeAddr("safe");
    address internal attacker = makeAddr("attacker");
    address internal friend = makeAddr("friend");
    address internal proxy = makeAddr("baseProxy");

    function setUp() public {
        vm.warp(T0);
        // The Reactive system contract has no code in tests, and Solidity
        // high-level calls revert on an extcodesize check against it. Etch a
        // single STOP opcode at SYSTEM so subscribe/requestCallback calls
        // become harmless no-ops (they return no data, so nothing is decoded).
        vm.etch(SYSTEM, hex"00");
        tokenBase = new MockToken("Base Demo USD", "bUSD");
        tokenUni = new MockToken("Unichain Demo USD", "uUSD");
        tokenNoAllowance = new MockToken("No Allowance", "NA");
        tokenBase.mint(watched, 1000 ether);
        tokenUni.mint(watched, 1000 ether);
        tokenNoAllowance.mint(watched, 500 ether);

        address[] memory baseTokens = new address[](1);
        baseTokens[0] = address(tokenBase);
        address[] memory uniTokens = new address[](1);
        uniTokens[0] = address(tokenUni);

        reactive = new TerifierReactive(watched, safe, THRESHOLD, baseTokens, uniTokens, address(0), address(0));

        address[] memory rescueTokens = new address[](2);
        rescueTokens[0] = address(tokenBase);
        rescueTokens[1] = address(tokenUni);
        rescuer = new TerifierRescuer(IPayable(payable(proxy)), address(reactive), watched, safe, rescueTokens);

        vm.prank(watched);
        tokenBase.approve(address(rescuer), type(uint256).max);
        vm.prank(watched);
        tokenUni.approve(address(rescuer), 300 ether);

        reactive.arm();
    }

    // ---- Log builders ----

    function _approvalLog(address spender_) internal view returns (IReactive.LogRecord memory) {
        return IReactive.LogRecord({
            chainId: BASE,
            contractAddress: address(tokenBase),
            topic0: reactive.APPROVAL_TOPIC_0(),
            topic1: uint256(uint160(watched)),
            topic2: uint256(uint160(spender_)),
            topic3: 0,
            data: abi.encode(uint256(100 ether)),
            blockNumber: block.number,
            opCode: 3,
            blockHash: 0,
            txHash: 0,
            logIndex: 0
        });
    }

    function _transferLog(address to_) internal view returns (IReactive.LogRecord memory) {
        return IReactive.LogRecord({
            chainId: BASE,
            contractAddress: address(tokenBase),
            topic0: reactive.TRANSFER_TOPIC_0(),
            topic1: uint256(uint160(watched)),
            topic2: uint256(uint160(to_)),
            topic3: 0,
            data: abi.encode(uint256(10 ether)),
            blockNumber: block.number,
            opCode: 3,
            blockHash: 0,
            txHash: 0,
            logIndex: 0
        });
    }

    function _cronLog() internal view returns (IReactive.LogRecord memory) {
        return IReactive.LogRecord({
            chainId: block.chainid,
            contractAddress: LEGACY_SYSTEM,
            topic0: reactive.CRON100_TOPIC_0(),
            topic1: 0,
            topic2: 0,
            topic3: 0,
            data: abi.encode(block.number),
            blockNumber: block.number,
            opCode: 1,
            blockHash: 0,
            txHash: 0,
            logIndex: 0
        });
    }

    function _react(IReactive.LogRecord memory log_) internal {
        vm.prank(SYSTEM);
        reactive.react(log_);
    }

    // ---- Reactive: benign vs malicious events ----

    function testBenignApprovalUpdatesLastSeen() public {
        reactive.addAllowlisted(friend);
        vm.warp(T0 + 3600);
        _react(_approvalLog(friend));
        assertFalse(reactive.tripped());
        assertEq(reactive.lastSeen(), T0 + 3600);
    }

    function testBadApprovalTripsOnce() public {
        _react(_approvalLog(attacker));
        assertTrue(reactive.tripped());
        assertEq(reactive.lastTripReason(), reactive.REASON_BAD_APPROVAL());
        assertFalse(reactive.armed());

        // Second bad event must not re-trip (latch holds, reason unchanged).
        _react(_approvalLog(attacker));
        assertTrue(reactive.tripped());
        assertEq(reactive.lastTripReason(), reactive.REASON_BAD_APPROVAL());
    }

    function testBadTransferTrips() public {
        _react(_transferLog(attacker));
        assertTrue(reactive.tripped());
        assertEq(reactive.lastTripReason(), reactive.REASON_BAD_TRANSFER());
    }

    function testAllowlistedTransferDoesNotTrip() public {
        reactive.addAllowlisted(friend);
        vm.warp(T0 + 7200);
        _react(_transferLog(friend));
        assertFalse(reactive.tripped());
        assertEq(reactive.lastSeen(), T0 + 7200);
    }

    function testTransferToSafeDoesNotTrip() public {
        _react(_transferLog(safe));
        assertFalse(reactive.tripped());
    }

    function testDisarmedDoesNotTrip() public {
        reactive.disarm();
        _react(_approvalLog(attacker));
        assertFalse(reactive.tripped());
    }

    function testReactRejectsNonSystemCaller() public {
        // Build the log first: the getter calls inside _approvalLog() are
        // external calls and would consume the prank / expectRevert below.
        IReactive.LogRecord memory log_ = _approvalLog(attacker);
        vm.prank(attacker);
        vm.expectRevert();
        reactive.react(log_);
    }

    // ---- Reactive: CRON dead-man switch ----

    function testCronBeforeThresholdDoesNotTrip() public {
        vm.warp(T0 + 6 days);
        _react(_cronLog());
        assertFalse(reactive.tripped());
    }

    function testCronAfterThresholdTripsInactivity() public {
        vm.warp(T0 + 8 days);
        _react(_cronLog());
        assertTrue(reactive.tripped());
        assertEq(reactive.lastTripReason(), reactive.REASON_INACTIVITY());
    }

    function testBenignActivityResetsInactivityClock() public {
        reactive.addAllowlisted(friend);
        vm.warp(T0 + 6 days);
        _react(_approvalLog(friend)); // lastSeen = T0 + 6 days
        vm.warp(T0 + 12 days); // only 6 days since last activity
        _react(_cronLog());
        assertFalse(reactive.tripped());
    }

    // ---- Reactive: latch reset + owner guards ----

    function testResetTripAndRearm() public {
        _react(_approvalLog(attacker));
        assertTrue(reactive.tripped());
        reactive.resetTrip();
        assertFalse(reactive.tripped());
        assertEq(reactive.lastTripReason(), reactive.REASON_NONE());
        assertFalse(reactive.armed());
        reactive.arm();
        assertTrue(reactive.armed());
        reactive.addAllowlisted(friend);
        _react(_approvalLog(friend));
        assertFalse(reactive.tripped());
    }

    function testOwnerOnlySettersRevertForNonOwner() public {
        vm.prank(attacker);
        vm.expectRevert();
        reactive.setSafe(attacker);
        vm.prank(attacker);
        vm.expectRevert();
        reactive.addAllowlisted(attacker);
        vm.prank(attacker);
        vm.expectRevert();
        reactive.arm();
        vm.prank(attacker);
        vm.expectRevert();
        reactive.setRescuer(BASE, attacker);
    }

    function testAddRemoveToken() public {
        MockToken extra = new MockToken("Extra", "X");
        reactive.addToken(BASE, address(extra));
        assertTrue(reactive.isWatchedToken(BASE, address(extra)));
        reactive.removeToken(BASE, address(extra));
        assertFalse(reactive.isWatchedToken(BASE, address(extra)));
    }

    // ---- Rescuer ----

    function testRescuerMovesMinBalanceAllowance() public {
        // Hoist the getter: it is an external call and would consume the prank.
        uint8 reason = reactive.REASON_BAD_APPROVAL();
        vm.prank(proxy);
        rescuer.rescue(address(reactive), reason);
        // tokenBase: balance 1000, allowance max -> 1000 rescued.
        assertEq(tokenBase.balanceOf(safe), 1000 ether);
        assertEq(tokenBase.balanceOf(watched), 0);
        // tokenUni: balance 1000, allowance 300 -> only 300 rescued.
        assertEq(tokenUni.balanceOf(safe), 300 ether);
        assertEq(tokenUni.balanceOf(watched), 700 ether);
    }

    function testRescuerSkipsZeroAllowanceToken() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(tokenNoAllowance);
        TerifierRescuer solo = new TerifierRescuer(IPayable(payable(proxy)), address(reactive), watched, safe, tokens);
        uint8 reason = reactive.REASON_BAD_TRANSFER();
        vm.prank(proxy);
        solo.rescue(address(reactive), reason);
        assertEq(tokenNoAllowance.balanceOf(safe), 0);
        assertEq(tokenNoAllowance.balanceOf(watched), 500 ether);
    }

    function testRescuerRejectsNonProxyCaller() public {
        uint8 reason = reactive.REASON_BAD_APPROVAL();
        vm.prank(attacker);
        vm.expectRevert();
        rescuer.rescue(address(reactive), reason);
    }

    function testRescuerRejectsWrongReactiveSender() public {
        uint8 reason = reactive.REASON_BAD_APPROVAL();
        vm.prank(proxy);
        vm.expectRevert();
        rescuer.rescue(attacker, reason);
    }

    function testRescuerOwnerOnly() public {
        vm.prank(attacker);
        vm.expectRevert();
        rescuer.setSafe(attacker);
        vm.prank(attacker);
        vm.expectRevert();
        rescuer.addToken(address(tokenBase));
    }
}
