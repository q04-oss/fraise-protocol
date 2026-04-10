// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IFraiseToken
/// @notice Interface for the $FRAISE ERC-20 token.
/// @dev Phase 1: USDC-bridged. Phase 2: gold-backed via upgrade.
interface IFraiseToken is IERC20 {
    // ─── Events ───────────────────────────────────────────────────────────────

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event GoldReserveUpdated(string uri, uint256 timestamp);

    // ─── Errors ───────────────────────────────────────────────────────────────

    error NotMinter();
    error ZeroAmount();
    error ZeroAddress();

    // ─── Functions ────────────────────────────────────────────────────────────

    /// @notice Mint tokens. Only callable by MINTER_ROLE.
    function mint(address to, uint256 amount) external;

    /// @notice Burn tokens from an address. Only callable by MINTER_ROLE.
    function burn(address from, uint256 amount) external;

    /// @notice Update the gold reserve attestation URI (Phase 2).
    function updateGoldReserve(string calldata uri) external;

    /// @notice URI pointing to the off-chain gold reserve attestation.
    function goldReserveURI() external view returns (string memory);

    /// @notice Timestamp of the last gold reserve attestation update.
    function goldReserveTimestamp() external view returns (uint256);
}
