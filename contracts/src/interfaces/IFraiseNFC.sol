// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/// @title IFraiseNFC
/// @notice Interface for on-chain NFC scan event recording.
interface IFraiseNFC {
    // ─── Structs ──────────────────────────────────────────────────────────────

    struct ScanEvent {
        uint256 scanId;
        bytes32 tagId;
        bytes32 varietyId;
        bytes32 farmId;
        address beneficiary;
        uint256 timestamp;
    }

    // ─── Events ───────────────────────────────────────────────────────────────

    event NFCScanRecorded(
        uint256 indexed scanId,
        bytes32 indexed tagId,
        bytes32 varietyId,
        bytes32 farmId,
        address indexed beneficiary,
        uint256 timestamp
    );

    event DeviceAdded(address indexed device);
    event DeviceRevoked(address indexed device);

    // ─── Errors ───────────────────────────────────────────────────────────────

    error NotADevice();
    error CooldownActive(uint256 nextAllowedAt);
    error ContractPaused();
    error DeviceRateLimitExceeded();
    error ZeroAddress();

    // ─── Functions ────────────────────────────────────────────────────────────

    /// @notice Record an NFC scan event. Only callable by a device with DEVICE_ROLE.
    function recordScan(
        bytes32 tagId,
        bytes32 varietyId,
        bytes32 farmId,
        address beneficiary
    ) external returns (uint256 scanId);

    /// @notice Get the last scan timestamp for a tag.
    function lastScanAt(bytes32 tagId) external view returns (uint256);

    /// @notice Get the total number of scans recorded.
    function totalScans() external view returns (uint256);
}
