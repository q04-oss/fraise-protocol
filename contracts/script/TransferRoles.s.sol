// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script, console2 } from "forge-std/Script.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

/// @notice Transfers DEFAULT_ADMIN_ROLE on all fraise-protocol contracts from the
///         deployer wallet to a Safe multisig, and rotates TimelockController
///         proposer/executor roles.
///
/// Required env vars:
///   PRIVATE_KEY             — Deployer private key (current role holder)
///   SAFE_ADDRESS            — Target Safe multisig address
///   TIMELOCK_ADDRESS        — Deployed TimelockController address
///   IDENTITY_ADDRESS        — Deployed FraiseIdentity address
///   TIME_CREDITS_ADDRESS    — Deployed FraiseTimeCredits address
///   NFC_ADDRESS             — Deployed FraiseNFC address
///   TOKEN_ADDRESS           — Deployed FraiseToken proxy address
///   PAYMENTS_ADDRESS        — Deployed FraisePayments address
///
/// Run:
///   forge script contracts/script/TransferRoles.s.sol --rpc-url $RPC_URL --broadcast
contract TransferRoles is Script {
    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 constant PROPOSER_ROLE  = keccak256("PROPOSER_ROLE");
    bytes32 constant EXECUTOR_ROLE  = keccak256("EXECUTOR_ROLE");
    bytes32 constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");

    function run() external {
        address safe    = vm.envAddress("SAFE_ADDRESS");
        address timelock = vm.envAddress("TIMELOCK_ADDRESS");
        address identity = vm.envAddress("IDENTITY_ADDRESS");
        address timeCredits = vm.envAddress("TIME_CREDITS_ADDRESS");
        address nfc     = vm.envAddress("NFC_ADDRESS");
        address token   = vm.envAddress("TOKEN_ADDRESS");
        address payments = vm.envAddress("PAYMENTS_ADDRESS");

        require(safe != address(0), "SAFE_ADDRESS not set");

        uint256 deployerPk = vm.envUint("PRIVATE_KEY");
        address deployer   = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        // ── AccessControl contracts (FraiseIdentity, FraiseTimeCredits, FraiseNFC,
        //    FraiseToken proxy, FraisePayments) ────────────────────────────────────
        address[5] memory contracts = [identity, timeCredits, nfc, token, payments];
        for (uint256 i = 0; i < contracts.length; i++) {
            AccessControl ac = AccessControl(contracts[i]);
            ac.grantRole(DEFAULT_ADMIN_ROLE, safe);
            ac.revokeRole(DEFAULT_ADMIN_ROLE, deployer);
        }

        // ── TimelockController ────────────────────────────────────────────────────
        // Grant Safe proposer + executor + canceller roles, then revoke from deployer.
        // The timelock admin (DEFAULT_ADMIN_ROLE) was set to address(0) at deploy,
        // so no admin role to transfer.
        TimelockController tc = TimelockController(payable(timelock));
        tc.grantRole(PROPOSER_ROLE,  safe);
        tc.grantRole(EXECUTOR_ROLE,  safe);
        tc.grantRole(CANCELLER_ROLE, safe);
        tc.revokeRole(PROPOSER_ROLE,  deployer);
        tc.revokeRole(EXECUTOR_ROLE,  deployer);
        // Note: deployer was never granted CANCELLER_ROLE at deploy — skip revoke.

        vm.stopBroadcast();

        console2.log("=== fraise-protocol Role Transfer ===");
        console2.log("Safe (new admin):     ", safe);
        console2.log("Deployer (revoked):   ", deployer);
        console2.log("TimelockController:   ", timelock);
        console2.log("FraiseIdentity:       ", identity);
        console2.log("FraiseTimeCredits:    ", timeCredits);
        console2.log("FraiseNFC:            ", nfc);
        console2.log("FraiseToken:          ", token);
        console2.log("FraisePayments:       ", payments);
    }
}
