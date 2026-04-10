// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { IFraiseNFC } from "./interfaces/IFraiseNFC.sol";
import { IFraiseTimeCredits } from "./interfaces/IFraiseTimeCredits.sol";

/// @title FraiseNFC
/// @notice Records NFC scan verification events on Optimism.
/// @dev Security model: each authorized physical device holds a private key and submits
///      scan transactions directly. A compromised device key is the primary attack surface.
///      Mitigations:
///        1. Per-tag cooldown (MIN_SCAN_INTERVAL) prevents same-tag double-fire.
///        2. Per-device hourly rate limit prevents a compromised key from spamming scans.
///        3. Admin can revoke a device instantly via revokeDevice().
///        4. Circuit breaker (Pausable) halts all scans if an attack is detected.
///
///      Future: NTAG DNA on-chip authentication can be added via the optional `authenticity`
///      field in a v2 recordScan signature. The current interface documents this path.
///
/// Timestamp note: block.timestamp is used for anti-replay and rate limiting.
///      ±15s manipulation by the sequencer does not constitute a meaningful attack
///      given MIN_SCAN_INTERVAL = 300s. This is acknowledged and accepted.
contract FraiseNFC is AccessControl, Pausable, IFraiseNFC {
    // ─── Roles ────────────────────────────────────────────────────────────────

    bytes32 public constant DEVICE_ROLE = keccak256("DEVICE_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    // ─── Constants ────────────────────────────────────────────────────────────

    /// @notice Minimum seconds between two scans of the same physical tag.
    uint256 public constant MIN_SCAN_INTERVAL = 300;

    /// @notice Maximum scans a single device may submit per hour.
    uint256 public constant MAX_SCANS_PER_HOUR = 500;

    // ─── Storage ──────────────────────────────────────────────────────────────

    IFraiseTimeCredits public immutable timeCredits;

    /// @dev Credits awarded per NFC scan in seconds (default: 30 days).
    uint256 public scanCreditSeconds = 30 days;

    /// @dev Monotonic scan counter used as scanId.
    uint256 private _scanCounter;

    /// @dev tagId → last scan timestamp (anti-replay).
    mapping(bytes32 => uint256) private _lastScanAt;

    /// @dev device → hour bucket → scan count (rate limiting).
    mapping(address => mapping(uint256 => uint256)) private _deviceHourlyCount;

    // ─── Constructor ──────────────────────────────────────────────────────────

    /// @param admin        Multisig Safe address.
    /// @param timeCredits_ Deployed FraiseTimeCredits contract address.
    constructor(address admin, address timeCredits_) {
        if (admin == address(0) || timeCredits_ == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        timeCredits = IFraiseTimeCredits(timeCredits_);
    }

    // ─── External: Write ──────────────────────────────────────────────────────

    /// @inheritdoc IFraiseNFC
    /// @dev Checks: not paused → device role → tag cooldown → device rate limit → record.
    function recordScan(
        bytes32 tagId,
        bytes32 varietyId,
        bytes32 farmId,
        address beneficiary
    ) external whenNotPaused onlyRole(DEVICE_ROLE) returns (uint256 scanId) {
        if (beneficiary == address(0)) revert ZeroAddress();

        // Anti-replay: enforce per-tag cooldown
        uint256 last = _lastScanAt[tagId];
        if (last != 0 && block.timestamp - last < MIN_SCAN_INTERVAL) {
            revert CooldownActive(last + MIN_SCAN_INTERVAL);
        }

        // Rate limit: max scans per device per hour
        uint256 hourBucket = block.timestamp / 1 hours;
        uint256 count = _deviceHourlyCount[msg.sender][hourBucket];
        if (count >= MAX_SCANS_PER_HOUR) revert DeviceRateLimitExceeded();

        // Effects
        scanId = ++_scanCounter;
        _lastScanAt[tagId] = block.timestamp;
        _deviceHourlyCount[msg.sender][hourBucket] = count + 1;

        emit NFCScanRecorded(scanId, tagId, varietyId, farmId, beneficiary, block.timestamp);

        // Credit the beneficiary — external call after effects (CEI pattern).
        // FraiseTimeCredits.credit() is trusted (internal contract, CREDIT_SOURCE_ROLE gated).
        timeCredits.credit(beneficiary, scanCreditSeconds);
    }

    /// @notice Add a device. Admin only.
    function addDevice(address device) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (device == address(0)) revert ZeroAddress();
        _grantRole(DEVICE_ROLE, device);
        emit DeviceAdded(device);
    }

    /// @notice Revoke a device immediately. Admin only.
    function revokeDevice(address device) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(DEVICE_ROLE, device);
        emit DeviceRevoked(device);
    }

    /// @notice Update credits awarded per scan. Admin only.
    function setScanCreditSeconds(uint256 seconds_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        scanCreditSeconds = seconds_;
    }

    /// @notice Pause all scans (emergency circuit breaker).
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /// @notice Unpause.
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // ─── External: Read ───────────────────────────────────────────────────────

    /// @inheritdoc IFraiseNFC
    function lastScanAt(bytes32 tagId) external view returns (uint256) {
        return _lastScanAt[tagId];
    }

    /// @inheritdoc IFraiseNFC
    function totalScans() external view returns (uint256) {
        return _scanCounter;
    }
}
