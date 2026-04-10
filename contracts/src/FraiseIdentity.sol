// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { IFraiseIdentity } from "./interfaces/IFraiseIdentity.sol";

/// @title FraiseIdentity
/// @notice Registry linking fraise.box labels to Optimism wallet addresses.
/// @dev Labels are stored normalized (lowercase enforced off-chain by the registrar).
///      First registration wins — no updates without explicit admin revocation.
///      Timestamp dependence: block.timestamp is used for event logging only, not for
///      any security-critical logic.
contract FraiseIdentity is AccessControl, IFraiseIdentity {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // ─── Roles ────────────────────────────────────────────────────────────────

    bytes32 public constant REGISTRAR_ROLE = keccak256("REGISTRAR_ROLE");

    // ─── Storage ──────────────────────────────────────────────────────────────

    /// @dev wallet → label string
    mapping(address => string) private _walletToLabel;

    /// @dev labelHash → wallet
    mapping(bytes32 => address) private _labelHashToWallet;

    // ─── Constructor ──────────────────────────────────────────────────────────

    /// @param admin         Address granted DEFAULT_ADMIN_ROLE (use a multisig Safe).
    /// @param registrar     Address granted REGISTRAR_ROLE (maison-fraise backend).
    constructor(address admin, address registrar) {
        if (admin == address(0) || registrar == address(0)) revert ZeroAddress();
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(REGISTRAR_ROLE, registrar);
    }

    // ─── External: Write ──────────────────────────────────────────────────────

    /// @inheritdoc IFraiseIdentity
    /// @dev Registrar pays gas; used for migration-era bulk registration.
    function registerIdentity(address wallet, string calldata label)
        external
        onlyRole(REGISTRAR_ROLE)
    {
        _register(wallet, label);
    }

    /// @inheritdoc IFraiseIdentity
    /// @dev User pays their own gas. The registrar signs the (wallet, label) pair
    ///      off-chain to prevent squatting of arbitrary labels.
    ///      Message format: keccak256(abi.encodePacked(wallet, label))
    function selfRegister(string calldata label, bytes calldata registrarSig) external {
        bytes32 msgHash = keccak256(abi.encodePacked(msg.sender, label))
            .toEthSignedMessageHash();
        address signer = msgHash.recover(registrarSig);
        if (!hasRole(REGISTRAR_ROLE, signer)) revert InvalidSignature();
        _register(msg.sender, label);
    }

    /// @inheritdoc IFraiseIdentity
    function revokeIdentity(address wallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        string memory label = _walletToLabel[wallet];
        if (bytes(label).length == 0) revert IdentityNotFound();
        bytes32 labelHash = keccak256(bytes(label));
        delete _walletToLabel[wallet];
        delete _labelHashToWallet[labelHash];
        emit IdentityRevoked(wallet, labelHash);
    }

    // ─── External: Read ───────────────────────────────────────────────────────

    /// @inheritdoc IFraiseIdentity
    function getWallet(string calldata label) external view returns (address) {
        return _labelHashToWallet[keccak256(bytes(label))];
    }

    /// @inheritdoc IFraiseIdentity
    function getLabel(address wallet) external view returns (string memory) {
        return _walletToLabel[wallet];
    }

    /// @inheritdoc IFraiseIdentity
    function isAvailable(string calldata label) external view returns (bool) {
        return _labelHashToWallet[keccak256(bytes(label))] == address(0);
    }

    // ─── Internal ─────────────────────────────────────────────────────────────

    function _register(address wallet, string calldata label) internal {
        if (wallet == address(0)) revert ZeroAddress();
        if (bytes(label).length == 0) revert InvalidLabel();

        bytes32 labelHash = keccak256(bytes(label));

        if (_labelHashToWallet[labelHash] != address(0)) revert LabelAlreadyTaken();
        if (bytes(_walletToLabel[wallet]).length != 0) revert WalletAlreadyRegistered();

        _walletToLabel[wallet] = label;
        _labelHashToWallet[labelHash] = wallet;

        emit IdentityRegistered(wallet, labelHash, label);
    }
}
