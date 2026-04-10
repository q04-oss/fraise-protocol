// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title IFraiseTimeCredits
/// @notice Interface for the non-transferable time credit balance system.
interface IFraiseTimeCredits {
    // ─── Enums ────────────────────────────────────────────────────────────────

    enum Tier {
        None,
        Standard,
        Reserve,
        Estate
    }

    // ─── Events ───────────────────────────────────────────────────────────────

    event CreditsAdded(address indexed user, uint256 amount, uint256 newSnapshot, uint256 lifetimeTotal);

    // ─── Errors ───────────────────────────────────────────────────────────────

    error NotAuthorizedCreditSource();
    error ZeroAmount();
    error ZeroAddress();

    // ─── Functions ────────────────────────────────────────────────────────────

    /// @notice Add time credits to a user. Only callable by authorized sources (FraiseNFC).
    function credit(address user, uint256 seconds_) external;

    /// @notice Get the current live balance (accounts for time drain since last update).
    function currentBalance(address user) external view returns (uint256);

    /// @notice Get the user's all-time lifetime credits in seconds.
    function lifetimeCredits(address user) external view returns (uint256);

    /// @notice Get the user's current tier based on live balance.
    function getTier(address user) external view returns (Tier);
}
