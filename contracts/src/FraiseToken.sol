// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC20Upgradeable } from
    "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { AccessControlUpgradeable } from
    "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from
    "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from
    "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { IFraiseToken } from "./interfaces/IFraiseToken.sol";

/// @title FraiseToken
/// @notice $FRAISE ERC-20 token with a two-phase architecture.
///
/// Phase 1 (USDC bridge): MINTER_ROLE mints/burns 1:1 with USDC deposits.
///         Decimals = 6 to match USDC. Users hold $FRAISE backed by locked USDC.
///
/// Phase 2 (Gold-backed): Upgrade the implementation via UUPS.
///         MINTER_ROLE transfers to a GoldReserveOracle. goldReserveURI is updated
///         with each third-party audit attestation.
///
/// Upgrade safety: _authorizeUpgrade is restricted to UPGRADER_ROLE which is held
/// exclusively by the TimelockController (48h delay). This ensures the community
/// has time to react to any upgrade proposal. UPGRADER_ROLE must never be granted
/// to an EOA. Audit concern SC-03 is addressed by this restriction.
///
/// @dev This contract is NOT intended to hold ETH or other tokens. Its only custody
///      is the $FRAISE token supply itself.
contract FraiseToken is
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IFraiseToken
{
    // ─── Roles ────────────────────────────────────────────────────────────────

    /// @notice Granted to the USDC bridge controller (Phase 1) or GoldReserveOracle (Phase 2).
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Granted exclusively to the TimelockController. Never grant to an EOA.
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // ─── Storage (append-only — do not reorder for upgrade safety) ───────────

    string private _goldReserveURI;
    uint256 private _goldReserveTimestamp;

    // ─── Initializer ──────────────────────────────────────────────────────────

    /// @param admin     Multisig Safe (DEFAULT_ADMIN_ROLE).
    /// @param upgrader  TimelockController address (UPGRADER_ROLE).
    /// @param minter    USDC bridge controller address (MINTER_ROLE, Phase 1).
    function initialize(address admin, address upgrader, address minter) external initializer {
        if (admin == address(0) || upgrader == address(0) || minter == address(0)) {
            revert ZeroAddress();
        }
        __ERC20_init("Fraise", "FRAISE");
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, upgrader);
        _grantRole(MINTER_ROLE, minter);
    }

    // ─── External: Write ──────────────────────────────────────────────────────

    /// @inheritdoc IFraiseToken
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        _mint(to, amount);
        emit Minted(to, amount);
    }

    /// @inheritdoc IFraiseToken
    function burn(address from, uint256 amount) external onlyRole(MINTER_ROLE) {
        if (from == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        _burn(from, amount);
        emit Burned(from, amount);
    }

    /// @inheritdoc IFraiseToken
    function updateGoldReserve(string calldata uri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _goldReserveURI = uri;
        _goldReserveTimestamp = block.timestamp;
        emit GoldReserveUpdated(uri, block.timestamp);
    }

    // ─── External: Read ───────────────────────────────────────────────────────

    /// @inheritdoc IFraiseToken
    function goldReserveURI() external view returns (string memory) {
        return _goldReserveURI;
    }

    /// @inheritdoc IFraiseToken
    function goldReserveTimestamp() external view returns (uint256) {
        return _goldReserveTimestamp;
    }

    /// @dev $FRAISE uses 6 decimals to match USDC in Phase 1.
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    // ─── Internal ─────────────────────────────────────────────────────────────

    /// @dev Restricted to UPGRADER_ROLE (TimelockController with 48h delay).
    ///      This function is the sole gate on the upgrade path. Never grant
    ///      UPGRADER_ROLE to an EOA.
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
}
