// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IFraiseTimeCredits } from "./interfaces/IFraiseTimeCredits.sol";

/// @title FraiseTimeCredits
/// @notice Non-transferable time credit balances that drain in real-time.
/// @dev Mirrors the socialTier.ts logic from the maison-fraise backend exactly:
///      - Credits accumulate from NFC scan events.
///      - Balance drains at 1 second per second (linear decay).
///      - Tier thresholds: Standard ≥ 1 day, Reserve ≥ 30 days, Estate ≥ 75 days.
///      - Credits are non-transferable by design. No ERC-20 interface.
///
/// Timestamp note: block.timestamp is used for drain calculation. On Optimism,
/// sequencer-controlled timestamps are bounded by L1 and cannot deviate by more
/// than ~15 seconds. This is negligible given the minimum NFC cooldown of 300s
/// and tier thresholds measured in days. This dependence is acknowledged and accepted.
contract FraiseTimeCredits is AccessControl, IFraiseTimeCredits {
    // ─── Roles ────────────────────────────────────────────────────────────────

    /// @notice Granted to FraiseNFC contract — the only authorized credit source.
    bytes32 public constant CREDIT_SOURCE_ROLE = keccak256("CREDIT_SOURCE_ROLE");

    // ─── Tier thresholds (in seconds) ─────────────────────────────────────────

    uint256 public constant STANDARD_THRESHOLD = 1 days;
    uint256 public constant RESERVE_THRESHOLD = 30 days;
    uint256 public constant ESTATE_THRESHOLD = 75 days;

    // ─── Storage ──────────────────────────────────────────────────────────────

    struct BalanceRecord {
        uint256 snapshot;          // stored seconds at snapshotAt
        uint256 snapshotAt;        // block.timestamp when snapshot was taken
        uint256 lifetimeCredits;   // all-time credits, never decreases
    }

    mapping(address => BalanceRecord) private _records;

    // ─── Constructor ──────────────────────────────────────────────────────────

    constructor(address admin) {
        if (admin == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    // ─── External: Write ──────────────────────────────────────────────────────

    /// @inheritdoc IFraiseTimeCredits
    function credit(address user, uint256 seconds_) external onlyRole(CREDIT_SOURCE_ROLE) {
        if (user == address(0)) revert ZeroAddress();
        if (seconds_ == 0) revert ZeroAmount();

        BalanceRecord storage r = _records[user];

        // Compute live balance before adding new credits
        uint256 live = _computeLiveBalance(r);
        uint256 newSnapshot = live + seconds_;
        uint256 newLifetime = r.lifetimeCredits + seconds_;

        r.snapshot = newSnapshot;
        r.snapshotAt = block.timestamp;
        r.lifetimeCredits = newLifetime;

        emit CreditsAdded(user, seconds_, newSnapshot, newLifetime);
    }

    // ─── External: Read ───────────────────────────────────────────────────────

    /// @inheritdoc IFraiseTimeCredits
    function currentBalance(address user) external view returns (uint256) {
        return _computeLiveBalance(_records[user]);
    }

    /// @inheritdoc IFraiseTimeCredits
    function lifetimeCredits(address user) external view returns (uint256) {
        return _records[user].lifetimeCredits;
    }

    /// @inheritdoc IFraiseTimeCredits
    function getTier(address user) external view returns (Tier) {
        uint256 balance = _computeLiveBalance(_records[user]);
        if (balance >= ESTATE_THRESHOLD) return Tier.Estate;
        if (balance >= RESERVE_THRESHOLD) return Tier.Reserve;
        if (balance >= STANDARD_THRESHOLD) return Tier.Standard;
        return Tier.None;
    }

    // ─── Internal ─────────────────────────────────────────────────────────────

    /// @dev Computes the live balance accounting for elapsed drain since last snapshot.
    ///      Uses unchecked subtraction with a floor-at-zero guard.
    ///      No overflow risk: snapshot and elapsed are both uint256 seconds,
    ///      and snapshot can never exceed all credits ever added (bounded by credit() calls).
    function _computeLiveBalance(BalanceRecord storage r) internal view returns (uint256) {
        if (r.snapshotAt == 0) return 0;
        uint256 elapsed = block.timestamp - r.snapshotAt;
        if (elapsed >= r.snapshot) return 0;
        return r.snapshot - elapsed;
    }
}
