// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title IFraisePayments
/// @notice Interface for currency-agnostic commerce payments.
interface IFraisePayments {
    // ─── Events ───────────────────────────────────────────────────────────────

    event PaymentMade(
        bytes32 indexed ref,
        address indexed payer,
        address indexed recipient,
        address token,
        uint256 amount,
        uint256 fee
    );

    event PaymentTokenAdded(address indexed token);
    event PaymentTokenRemoved(address indexed token);
    event FeeUpdated(uint256 newFeeBps);
    event FeeCollectorUpdated(address indexed newCollector);

    // ─── Errors ───────────────────────────────────────────────────────────────

    error TokenNotSupported();
    error ZeroAmount();
    error ZeroAddress();
    error FeeTooHigh();
    error TransferFailed();

    // ─── Functions ────────────────────────────────────────────────────────────

    /// @notice Execute a payment. Caller must pre-approve this contract.
    /// @param token     ERC-20 token address (must be whitelisted).
    /// @param amount    Gross amount (fee is deducted from this).
    /// @param recipient Payment recipient.
    /// @param ref       Off-chain order reference (keccak256 of order UUID).
    function pay(address token, uint256 amount, address recipient, bytes32 ref) external;

    /// @notice Add a supported payment token (owner only).
    function addPaymentToken(address token) external;

    /// @notice Remove a supported payment token (owner only).
    function removePaymentToken(address token) external;

    /// @notice Check if a token is supported.
    function isSupported(address token) external view returns (bool);

    /// @notice Get all supported tokens.
    function supportedTokens() external view returns (address[] memory);

    /// @notice Current fee in basis points (max 1000 = 10%).
    function feeBps() external view returns (uint256);
}
