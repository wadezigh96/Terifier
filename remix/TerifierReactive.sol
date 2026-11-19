// SPDX-License-Identifier: MIT
// Remix-ready copy: @reactive imports point at the pinned reactive-lib-omni v0.1.0 commit on GitHub.
// Upload this file to remix.ethereum.org — no Foundry needed. See docs/REMIX.md for deploy steps.
pragma solidity ^0.8.29;

import { ISystemContract } from "https://github.com/Reactive-Network/reactive-lib-omni/blob/3ade0dcf1d27e67e5783ef807e73a1b9e0c0cce8/src/interfaces/ISystemContract.sol";
import { IReactive } from "https://github.com/Reactive-Network/reactive-lib-omni/blob/3ade0dcf1d27e67e5783ef807e73a1b9e0c0cce8/src/interfaces/IReactive.sol";
import { AbstractReactive } from "https://github.com/Reactive-Network/reactive-lib-omni/blob/3ade0dcf1d27e67e5783ef807e73a1b9e0c0cce8/src/base/AbstractReactive.sol";

/// @title Terifier Sentinel — reactive watchdog for one wallet, across chains.
/// @notice Lives on Reactive Lasna. Watches ERC-20 Approval / Transfer events
///         for a single wallet on Base Sepolia and Unichain Sepolia, plus a
///         CRON dead-man switch. On a bad event it trips exactly once and asks
///         the system contract to callback a TerifierRescuer on every chain
///         that has one wired, moving the wallet's remaining tokens to safety.
/// @dev Built from scratch for the Reactive Omni Buildathon, track
///      "Set It and Forget It". Reactive Omni API (docs: dev.reactive.network):
///      SYSTEM = 0x8888888888888888888888888888888888888888, react() is
///      onlySystem, callbacks are requested via SYSTEM.requestCallbackV_1_0
///      with the first payload argument as an address(0) placeholder.
contract TerifierReactive is AbstractReactive {
    // ---- Chains watched (testnet only; mainnet and testnet must not mix) ----
    uint256 public constant BASE_SEPOLIA_CHAIN_ID = 84532;
    uint256 public constant UNICHAIN_SEPOLIA_CHAIN_ID = 1301;

    // ---- Trip reasons (uint8, carried in the Tripped event and the callback) ----
    uint8 public constant REASON_NONE = 0;
    uint8 public constant REASON_BAD_APPROVAL = 1;
    uint8 public constant REASON_BAD_TRANSFER = 2;
    uint8 public constant REASON_INACTIVITY = 3;

    // ---- Event topics ----
    uint256 public constant APPROVAL_TOPIC_0 = uint256(keccak256("Approval(address,address,uint256)"));
    uint256 public constant TRANSFER_TOPIC_0 = uint256(keccak256("Transfer(address,address,uint256)"));

    // ---- CRON (legacy system contract emits Cron events; Cron100 ~ every 2 min) ----
    address internal constant LEGACY_SYSTEM_ADDR = 0x0000000000000000000000000000000000fffFfF;
    uint256 public constant CRON100_TOPIC_0 =
        0xb49937fb8970e19fd46d48f7e3fb00d659deac0347f79cd7cb542f0fc1503c70;

    // Minimum callback gas enforced by Reactive Network is 100,000; 1,000,000
    // comfortably covers a multi-token rescue on the destination chain.
    uint64 internal constant CALLBACK_GAS_LIMIT = 1_000_000;

    /// @notice Default dead-man threshold: 7 days of wallet inactivity.
    uint256 public constant DEFAULT_INACTIVITY_THRESHOLD = 7 days;

    address public owner;
    address public watchedWallet;
    address public safeAddress;

    /// @notice When false, react() never trips (deploy default: disarmed).
    bool public armed;
    /// @notice Trip-once latch. Set on trip, cleared only by resetTrip().
    bool public tripped;
    uint8 public lastTripReason;
    /// @notice Timestamp of the last benign wallet activity (or arm()).
    uint256 public lastSeen;
    /// @notice Seconds of inactivity after which a CRON tick trips INACTIVITY.
    uint256 public inactivityThreshold;

    mapping(address => bool) public allowlisted;
    mapping(uint256 => address) public rescuerByChain;
    mapping(uint256 => mapping(address => bool)) public isWatchedToken;
    mapping(uint256 => address[]) internal _tokensByChain;
    uint256[] internal _watchedChains;

    event Tripped(uint8 indexed reason, uint256 indexed chainId, address indexed token, uint256 timestamp);
    event Armed(uint256 lastSeen);
    event Disarmed();
    event TripReset();
    event SafeUpdated(address indexed safe);
    event AllowlistUpdated(address indexed account, bool allowed);
    event TokenAdded(uint256 indexed chainId, address indexed token);
    event TokenRemoved(uint256 indexed chainId, address indexed token);
    event RescuerSet(uint256 indexed chainId, address indexed rescuer);
    event ThresholdUpdated(uint256 threshold);

    error NotOwner();
    error ZeroAddress();
    error UnsupportedChain(uint256 chainId);
    error TokenAlreadyWatched(uint256 chainId, address token);
    error TokenNotWatched(uint256 chainId, address token);
    error AlreadyTripped();
    error NotTripped();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @param watchedWallet_ Wallet under protection.
    /// @param safeAddress_ Rescue destination for all chains.
    /// @param inactivityThreshold_ Seconds of inactivity before a CRON trip.
    /// @param baseTokens_ ERC-20s to watch on Base Sepolia.
    /// @param unichainTokens_ ERC-20s to watch on Unichain Sepolia.
    /// @param baseRescuer_ TerifierRescuer on Base Sepolia (address(0) = set later).
    /// @param unichainRescuer_ TerifierRescuer on Unichain Sepolia (address(0) = set later).
    constructor(
        address watchedWallet_,
        address safeAddress_,
        uint256 inactivityThreshold_,
        address[] memory baseTokens_,
        address[] memory unichainTokens_,
        address baseRescuer_,
        address unichainRescuer_
    ) payable {
        if (watchedWallet_ == address(0) || safeAddress_ == address(0)) revert ZeroAddress();
        owner = msg.sender;
        watchedWallet = watchedWallet_;
        safeAddress = safeAddress_;
        inactivityThreshold = inactivityThreshold_;
        lastSeen = block.timestamp;

        _watchedChains.push(BASE_SEPOLIA_CHAIN_ID);
        _watchedChains.push(UNICHAIN_SEPOLIA_CHAIN_ID);
        rescuerByChain[BASE_SEPOLIA_CHAIN_ID] = baseRescuer_;
        rescuerByChain[UNICHAIN_SEPOLIA_CHAIN_ID] = unichainRescuer_;

        for (uint256 i = 0; i < baseTokens_.length; i++) {
            _addToken(BASE_SEPOLIA_CHAIN_ID, baseTokens_[i]);
        }
        for (uint256 i = 0; i < unichainTokens_.length; i++) {
            _addToken(UNICHAIN_SEPOLIA_CHAIN_ID, unichainTokens_[i]);
        }
        _subscribeCron();
    }

    // ---- Owner configuration ----

    function setSafe(address safeAddress_) external onlyOwner {
        if (safeAddress_ == address(0)) revert ZeroAddress();
        safeAddress = safeAddress_;
        emit SafeUpdated(safeAddress_);
    }

    function addAllowlisted(address account_) external onlyOwner {
        if (account_ == address(0)) revert ZeroAddress();
        allowlisted[account_] = true;
        emit AllowlistUpdated(account_, true);
    }

    function removeAllowlisted(address account_) external onlyOwner {
        allowlisted[account_] = false;
        emit AllowlistUpdated(account_, false);
    }

    function addToken(uint256 chainId_, address token_) external onlyOwner {
        _requireSupportedChain(chainId_);
        _addToken(chainId_, token_);
    }

    function removeToken(uint256 chainId_, address token_) external onlyOwner {
        _requireSupportedChain(chainId_);
        _removeToken(chainId_, token_);
    }

    function setRescuer(uint256 chainId_, address rescuer_) external onlyOwner {
        _requireSupportedChain(chainId_);
        rescuerByChain[chainId_] = rescuer_;
        emit RescuerSet(chainId_, rescuer_);
    }

    function setInactivityThreshold(uint256 threshold_) external onlyOwner {
        inactivityThreshold = threshold_;
        emit ThresholdUpdated(threshold_);
    }

    /// @notice Arms the watchdog. Resets the inactivity clock to now.
    function arm() external onlyOwner {
        if (tripped) revert AlreadyTripped();
        armed = true;
        lastSeen = block.timestamp;
        emit Armed(block.timestamp);
    }

    function disarm() external onlyOwner {
        armed = false;
        emit Disarmed();
    }

    /// @notice Clears the trip latch after a trip. Does NOT re-arm: call arm()
    ///         again once the wallet is safe. Re-arming also resets lastSeen.
    function resetTrip() external onlyOwner {
        if (!tripped) revert NotTripped();
        tripped = false;
        lastTripReason = REASON_NONE;
        emit TripReset();
    }

    /// @notice Settles outstanding debt to the system contract from this
    ///         contract's balance. A contract in debt receives no events.
    function coverDebt() external onlyOwner {
        _coverDebt();
    }

    // ---- Views ----

    function getTokens(uint256 chainId_) external view returns (address[] memory) {
        return _tokensByChain[chainId_];
    }

    function getWatchedChains() external view returns (uint256[] memory) {
        return _watchedChains;
    }

    // ---- Reactive entry point ----

    /// @inheritdoc IReactive
    function react(LogRecord memory log_) external onlySystem {
        if (log_.topic0 == CRON100_TOPIC_0) {
            _onCron();
            return;
        }
        if (log_.topic0 == APPROVAL_TOPIC_0) {
            _onApproval(log_);
            return;
        }
        if (log_.topic0 == TRANSFER_TOPIC_0) {
            _onTransfer(log_);
            return;
        }
        // Unknown topic: fall through. Never revert as a filter — a revert
        // is still billed for the gas burned (see Reactive docs).
    }

    function _onApproval(LogRecord memory log_) internal {
        if (log_.opCode != 3) return;
        if (address(uint160(log_.topic1)) != watchedWallet) return;
        if (!isWatchedToken[log_.chainId][log_.contractAddress]) return;
        address spender = address(uint160(log_.topic2));
        if (allowlisted[spender]) {
            lastSeen = block.timestamp;
            return;
        }
        _trip(REASON_BAD_APPROVAL, log_.chainId, log_.contractAddress);
    }

    function _onTransfer(LogRecord memory log_) internal {
        if (log_.opCode != 3) return;
        if (address(uint160(log_.topic1)) != watchedWallet) return;
        if (!isWatchedToken[log_.chainId][log_.contractAddress]) return;
        address to = address(uint160(log_.topic2));
        if (to == watchedWallet || to == safeAddress || allowlisted[to]) {
            lastSeen = block.timestamp;
            return;
        }
        _trip(REASON_BAD_TRANSFER, log_.chainId, log_.contractAddress);
    }

    function _onCron() internal {
        if (!armed || tripped) return;
        if (inactivityThreshold == 0) return;
        if (block.timestamp <= lastSeen) return;
        if (block.timestamp - lastSeen >= inactivityThreshold) {
            _trip(REASON_INACTIVITY, block.chainid, address(0));
        }
    }

    /// @notice Trip-once: sets the latch, disarms, emits Tripped, and requests
    ///         a rescue callback on every chain with a rescuer wired.
    function _trip(uint8 reason_, uint256 chainId_, address token_) internal {
        if (!armed || tripped) return;
        tripped = true;
        armed = false;
        lastTripReason = reason_;
        emit Tripped(reason_, chainId_, token_, block.timestamp);

        bytes memory payload = abi.encodeWithSignature("rescue(address,uint8)", address(0), reason_);
        for (uint256 i = 0; i < _watchedChains.length; i++) {
            uint256 dest = _watchedChains[i];
            address rescuer = rescuerByChain[dest];
            if (rescuer == address(0)) continue;
            SYSTEM.requestCallbackV_1_0(
                ISystemContract.CallbackConfiguration_V_1_0({
                    chainId: dest,
                    recipient: rescuer,
                    gasLimit: CALLBACK_GAS_LIMIT,
                    payload: payload
                })
            );
        }
    }

    // ---- Internals ----

    function _requireSupportedChain(uint256 chainId_) internal pure {
        if (chainId_ != BASE_SEPOLIA_CHAIN_ID && chainId_ != UNICHAIN_SEPOLIA_CHAIN_ID) {
            revert UnsupportedChain(chainId_);
        }
    }

    function _addToken(uint256 chainId_, address token_) internal {
        if (token_ == address(0)) revert ZeroAddress();
        if (isWatchedToken[chainId_][token_]) revert TokenAlreadyWatched(chainId_, token_);
        isWatchedToken[chainId_][token_] = true;
        _tokensByChain[chainId_].push(token_);
        uint256 ownerTopic = uint256(uint160(watchedWallet));
        SYSTEM.subscribe(chainId_, token_, APPROVAL_TOPIC_0, ownerTopic, REACTIVE_IGNORE, REACTIVE_IGNORE);
        SYSTEM.subscribe(chainId_, token_, TRANSFER_TOPIC_0, ownerTopic, REACTIVE_IGNORE, REACTIVE_IGNORE);
        emit TokenAdded(chainId_, token_);
    }

    function _removeToken(uint256 chainId_, address token_) internal {
        if (!isWatchedToken[chainId_][token_]) revert TokenNotWatched(chainId_, token_);
        isWatchedToken[chainId_][token_] = false;
        address[] storage tokens = _tokensByChain[chainId_];
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == token_) {
                tokens[i] = tokens[tokens.length - 1];
                tokens.pop();
                break;
            }
        }
        uint256 ownerTopic = uint256(uint160(watchedWallet));
        SYSTEM.unsubscribe(chainId_, token_, APPROVAL_TOPIC_0, ownerTopic, REACTIVE_IGNORE, REACTIVE_IGNORE);
        SYSTEM.unsubscribe(chainId_, token_, TRANSFER_TOPIC_0, ownerTopic, REACTIVE_IGNORE, REACTIVE_IGNORE);
        emit TokenRemoved(chainId_, token_);
    }

    function _subscribeCron() internal {
        SYSTEM.subscribe(
            block.chainid,
            LEGACY_SYSTEM_ADDR,
            CRON100_TOPIC_0,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
    }
}
