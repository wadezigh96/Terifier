// SPDX-License-Identifier: MIT
// Remix-ready copy: @reactive imports point at the pinned reactive-lib-omni v0.1.0 commit on GitHub.
// Upload this file to remix.ethereum.org — no Foundry needed. See docs/REMIX.md for deploy steps.
pragma solidity ^0.8.29;

import { IPayable } from "https://github.com/Reactive-Network/reactive-lib-omni/blob/3ade0dcf1d27e67e5783ef807e73a1b9e0c0cce8/src/interfaces/IPayable.sol";
import { AbstractCallback } from "https://github.com/Reactive-Network/reactive-lib-omni/blob/3ade0dcf1d27e67e5783ef807e73a1b9e0c0cce8/src/base/AbstractCallback.sol";

/// @notice Minimal ERC-20 interface used by the rescuer (no external deps).
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

/// @title TerifierRescuer — destination-chain rescue executor.
/// @notice One instance per destination chain. When the TerifierReactive
///         contract on Lasna trips, the callback proxy calls rescue() here.
///         For every registered token it pulls min(balance, allowance) from
///         the watched wallet into the safe address. One bad token can never
///         block the rest: each transfer is isolated with try/catch and a
///         RescueSkipped event.
/// @dev Auth: onlyServiceProvider (caller must be this chain's callback proxy)
///      AND onlyCallbackSender(reactive_) (injected sender must be the
///      TerifierReactive contract). The proxy overwrites the first payload
///      argument with the reactive contract's address.
contract TerifierRescuer is AbstractCallback {
    /// @notice Hard cap so one rescue callback stays inside its gas limit.
    uint256 public constant MAX_TOKENS = 16;

    address public owner;
    address public watchedWallet;
    address public safeAddress;

    address[] internal _tokens;
    mapping(address => bool) public isToken;

    event Rescued(address indexed token, uint256 amount, uint8 reason);
    event RescueSkipped(address indexed token, uint8 reason, string why);
    event TokenAdded(address indexed token);
    event TokenRemoved(address indexed token);
    event SafeUpdated(address indexed safe);
    event WatchedWalletUpdated(address indexed wallet);

    error NotOwner();
    error ZeroAddress();
    error TooManyTokens();
    error TokenAlreadyAdded(address token);
    error TokenNotAdded(address token);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @param callbackProxy_ This chain's callback proxy (service provider).
    /// @param callbackSender_ The TerifierReactive contract on Lasna.
    /// @param watchedWallet_ Wallet whose tokens are rescued.
    /// @param safeAddress_ Rescue destination.
    /// @param tokens_ ERC-20s this rescuer may pull (max 16).
    constructor(
        IPayable callbackProxy_,
        address callbackSender_,
        address watchedWallet_,
        address safeAddress_,
        address[] memory tokens_
    ) payable AbstractCallback(callbackProxy_, callbackSender_) {
        if (watchedWallet_ == address(0) || safeAddress_ == address(0)) revert ZeroAddress();
        owner = msg.sender;
        watchedWallet = watchedWallet_;
        safeAddress = safeAddress_;
        for (uint256 i = 0; i < tokens_.length; i++) {
            _addToken(tokens_[i]);
        }
    }

    /// @notice Rescue entry point, called by the callback proxy.
    /// @param reactive_ Injected by the proxy: the reactive contract that
    ///        requested this callback. Must equal _CALLBACK_SENDER.
    /// @param reason_ Trip reason code from TerifierReactive (1 = bad approval,
    ///        2 = bad transfer, 3 = inactivity).
    function rescue(address reactive_, uint8 reason_) external onlyServiceProvider onlyCallbackSender(reactive_) {
        for (uint256 i = 0; i < _tokens.length; i++) {
            address token = _tokens[i];
            uint256 balance = IERC20(token).balanceOf(watchedWallet);
            uint256 allowance = IERC20(token).allowance(watchedWallet, address(this));
            uint256 amount = balance < allowance ? balance : allowance;
            if (amount == 0) {
                emit RescueSkipped(token, reason_, "zero-rescuable");
                continue;
            }
            try IERC20(token).transferFrom(watchedWallet, safeAddress, amount) returns (bool ok) {
                if (ok) {
                    emit Rescued(token, amount, reason_);
                } else {
                    emit RescueSkipped(token, reason_, "returned-false");
                }
            } catch {
                emit RescueSkipped(token, reason_, "reverted");
            }
        }
    }

    // ---- Owner configuration ----

    function addToken(address token_) external onlyOwner {
        _addToken(token_);
    }

    function removeToken(address token_) external onlyOwner {
        if (!isToken[token_]) revert TokenNotAdded(token_);
        isToken[token_] = false;
        for (uint256 i = 0; i < _tokens.length; i++) {
            if (_tokens[i] == token_) {
                _tokens[i] = _tokens[_tokens.length - 1];
                _tokens.pop();
                break;
            }
        }
        emit TokenRemoved(token_);
    }

    function setSafe(address safeAddress_) external onlyOwner {
        if (safeAddress_ == address(0)) revert ZeroAddress();
        safeAddress = safeAddress_;
        emit SafeUpdated(safeAddress_);
    }

    function setWatchedWallet(address watchedWallet_) external onlyOwner {
        if (watchedWallet_ == address(0)) revert ZeroAddress();
        watchedWallet = watchedWallet_;
        emit WatchedWalletUpdated(watchedWallet_);
    }

    /// @notice Settles outstanding debt to the callback proxy from this
    ///         contract's balance. A contract in debt receives no callbacks.
    function coverDebt() external onlyOwner {
        _coverDebt();
    }

    function getTokens() external view returns (address[] memory) {
        return _tokens;
    }

    // ---- Internals ----

    function _addToken(address token_) internal {
        if (token_ == address(0)) revert ZeroAddress();
        if (isToken[token_]) revert TokenAlreadyAdded(token_);
        if (_tokens.length >= MAX_TOKENS) revert TooManyTokens();
        isToken[token_] = true;
        _tokens.push(token_);
        emit TokenAdded(token_);
    }
}
