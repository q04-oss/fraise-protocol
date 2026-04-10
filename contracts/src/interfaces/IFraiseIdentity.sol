// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title IFraiseIdentity
/// @notice Interface for the Fraise identity registry linking fraise.box labels to wallet addresses.
interface IFraiseIdentity {
    // ─── Events ───────────────────────────────────────────────────────────────

    /// @notice Emitted when a new identity is registered.
    event IdentityRegistered(address indexed wallet, bytes32 indexed labelHash, string label);

    /// @notice Emitted when an identity is revoked.
    event IdentityRevoked(address indexed wallet, bytes32 indexed labelHash);

    // ─── Errors ───────────────────────────────────────────────────────────────

    error ZeroAddress();
    error LabelAlreadyTaken();
    error WalletAlreadyRegistered();
    error IdentityNotFound();
    error InvalidLabel();
    error InvalidSignature();

    // ─── Functions ────────────────────────────────────────────────────────────

    /// @notice Register a fraise.box label for a wallet (registrar only).
    function registerIdentity(address wallet, string calldata label) external;

    /// @notice Self-register with a signed attestation from the registrar.
    function selfRegister(string calldata label, bytes calldata registrarSig) external;

    /// @notice Revoke an identity (admin only).
    function revokeIdentity(address wallet) external;

    /// @notice Resolve a label to a wallet address.
    function getWallet(string calldata label) external view returns (address);

    /// @notice Resolve a wallet address to its label.
    function getLabel(address wallet) external view returns (string memory);

    /// @notice Check if a label is available.
    function isAvailable(string calldata label) external view returns (bool);
}
