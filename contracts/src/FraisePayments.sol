// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Ownable2Step, Ownable } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IFraisePayments } from "./interfaces/IFraisePayments.sol";

/// @title FraisePayments
/// @notice Currency-agnostic payment router for Fraise commerce.
/// @dev This contract is intentionally NOT upgradeable. If a bug is found,
///      deploy a new contract and deprecate this one. This eliminates the
///      upgrade-path attack surface on user fund approvals (audit concern SC-04).
///
///      Only whitelisted ERC-20 tokens are accepted. At launch: USDC on Optimism.
///      When $FRAISE launches, it is added via addPaymentToken().
///
///      Token compatibility note: tokens with transfer fees or rebasing mechanisms
///      are NOT supported. The received-amount pattern (balance check before/after)
///      is used to guard against fee-on-transfer tokens. Rebasing tokens must not
///      be whitelisted. This constraint is documented here and must be enforced by
///      the owner during token whitelisting.
///
///      Reentrancy: nonReentrant guard is applied to pay(). The CEI pattern is
///      also observed: all state is updated before external token transfers.
contract FraisePayments is Ownable2Step, ReentrancyGuard, IFraisePayments {
    using SafeERC20 for IERC20;

    // ─── Constants ────────────────────────────────────────────────────────────

    uint256 public constant MAX_FEE_BPS = 1000; // 10%

    // ─── Storage ──────────────────────────────────────────────────────────────

    uint256 private _feeBps;
    address private _feeCollector;

    mapping(address => bool) private _supported;
    address[] private _tokenList;

    // ─── Constructor ──────────────────────────────────────────────────────────

    /// @param owner_        Multisig Safe.
    /// @param feeCollector_ Address that receives platform fees.
    /// @param initialFeeBps Platform fee in basis points (e.g. 200 = 2%).
    /// @param initialTokens Initial list of accepted ERC-20 tokens (e.g. [USDC]).
    constructor(
        address owner_,
        address feeCollector_,
        uint256 initialFeeBps,
        address[] memory initialTokens
    ) Ownable(owner_) {
        if (owner_ == address(0) || feeCollector_ == address(0)) revert ZeroAddress();
        if (initialFeeBps > MAX_FEE_BPS) revert FeeTooHigh();

        _feeCollector = feeCollector_;
        _feeBps = initialFeeBps;

        for (uint256 i = 0; i < initialTokens.length; i++) {
            _addToken(initialTokens[i]);
        }
    }

    // ─── External: Write ──────────────────────────────────────────────────────

    /// @inheritdoc IFraisePayments
    /// @dev Uses the received-amount pattern to handle any unexpected transfer discrepancy.
    ///      Under normal ERC-20 (non-fee tokens), balanceBefore + amount == balanceAfter.
    function pay(address token, uint256 amount, address recipient, bytes32 ref)
        external
        nonReentrant
    {
        if (!_supported[token]) revert TokenNotSupported();
        if (amount == 0) revert ZeroAmount();
        if (recipient == address(0)) revert ZeroAddress();

        // Compute fee
        uint256 fee = (amount * _feeBps) / 10_000;
        uint256 net = amount - fee;

        // Effects: emit before external calls (CEI)
        emit PaymentMade(ref, msg.sender, recipient, token, amount, fee);

        // Interactions: pull from payer, push to recipient and fee collector
        uint256 before = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = IERC20(token).balanceOf(address(this)) - before;

        // Use received amount to guard against fee-on-transfer tokens
        uint256 actualFee = (received * _feeBps) / 10_000;
        uint256 actualNet = received - actualFee;

        IERC20(token).safeTransfer(recipient, actualNet);
        if (actualFee > 0) {
            IERC20(token).safeTransfer(_feeCollector, actualFee);
        }
    }

    /// @inheritdoc IFraisePayments
    function addPaymentToken(address token) external onlyOwner {
        _addToken(token);
    }

    /// @inheritdoc IFraisePayments
    function removePaymentToken(address token) external onlyOwner {
        if (!_supported[token]) revert TokenNotSupported();
        _supported[token] = false;
        // Remove from list — order not preserved
        for (uint256 i = 0; i < _tokenList.length; i++) {
            if (_tokenList[i] == token) {
                _tokenList[i] = _tokenList[_tokenList.length - 1];
                _tokenList.pop();
                break;
            }
        }
        emit PaymentTokenRemoved(token);
    }

    /// @notice Update platform fee. Max 10%.
    function setFeeBps(uint256 newFeeBps) external onlyOwner {
        if (newFeeBps > MAX_FEE_BPS) revert FeeTooHigh();
        _feeBps = newFeeBps;
        emit FeeUpdated(newFeeBps);
    }

    /// @notice Update fee collector address.
    function setFeeCollector(address newCollector) external onlyOwner {
        if (newCollector == address(0)) revert ZeroAddress();
        _feeCollector = newCollector;
        emit FeeCollectorUpdated(newCollector);
    }

    // ─── External: Read ───────────────────────────────────────────────────────

    /// @inheritdoc IFraisePayments
    function isSupported(address token) external view returns (bool) {
        return _supported[token];
    }

    /// @inheritdoc IFraisePayments
    function supportedTokens() external view returns (address[] memory) {
        return _tokenList;
    }

    /// @inheritdoc IFraisePayments
    function feeBps() external view returns (uint256) {
        return _feeBps;
    }

    /// @notice Current fee collector address.
    function feeCollector() external view returns (address) {
        return _feeCollector;
    }

    // ─── Internal ─────────────────────────────────────────────────────────────

    function _addToken(address token) internal {
        if (token == address(0)) revert ZeroAddress();
        if (_supported[token]) return; // idempotent
        _supported[token] = true;
        _tokenList.push(token);
        emit PaymentTokenAdded(token);
    }
}
