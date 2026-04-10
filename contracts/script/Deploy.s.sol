// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script, console2 } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

import { FraiseIdentity } from "../src/FraiseIdentity.sol";
import { FraiseTimeCredits } from "../src/FraiseTimeCredits.sol";
import { FraiseNFC } from "../src/FraiseNFC.sol";
import { FraiseToken } from "../src/FraiseToken.sol";
import { FraisePayments } from "../src/FraisePayments.sol";

/// @title Deploy
/// @notice Full production deployment of the Fraise Protocol.
///
/// Required environment variables:
///   ADMIN_ADDRESS        — Multisig Safe address (DEFAULT_ADMIN_ROLE on all contracts)
///   REGISTRAR_ADDRESS    — Backend signer for selfRegister() flows
///   MINTER_ADDRESS       — USDC bridge controller (Phase 1)
///   FEE_COLLECTOR        — Address to receive platform fees
///   USDC_ADDRESS         — USDC token address on target network
///   TIMELOCK_MIN_DELAY   — Seconds for TimelockController delay (e.g. 172800 = 48h)
///
/// Run:
///   forge script contracts/script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify
contract Deploy is Script {
    // ─── Deployment outputs ───────────────────────────────────────────────────

    TimelockController public timelock;
    FraiseIdentity public identity;
    FraiseTimeCredits public timeCredits;
    FraiseNFC public nfc;
    FraiseToken public tokenImpl;
    FraiseToken public token; // proxy
    FraisePayments public payments;

    function run() external {
        // ── Load config from environment ──────────────────────────────────────
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address registrar = vm.envAddress("REGISTRAR_ADDRESS");
        address minter = vm.envAddress("MINTER_ADDRESS");
        address feeCollector = vm.envAddress("FEE_COLLECTOR");
        address usdc = vm.envAddress("USDC_ADDRESS");
        uint256 timelockDelay = vm.envUint("TIMELOCK_MIN_DELAY");
        uint256 feeBps = vm.envOr("FEE_BPS", uint256(200)); // default 2%

        vm.startBroadcast();

        // ── 1. TimelockController (holds UPGRADER_ROLE on FraiseToken) ────────
        //   proposers + executors = admin (Safe). Cancel = no one (governed by proposers).
        address[] memory proposers = new address[](1);
        proposers[0] = admin;
        address[] memory executors = new address[](1);
        executors[0] = admin;

        timelock = new TimelockController(timelockDelay, proposers, executors, address(0));
        console2.log("TimelockController:", address(timelock));

        // ── 2. FraiseIdentity ─────────────────────────────────────────────────
        identity = new FraiseIdentity(admin, registrar);
        console2.log("FraiseIdentity:    ", address(identity));

        // ── 3. FraiseTimeCredits ──────────────────────────────────────────────
        timeCredits = new FraiseTimeCredits(admin);
        console2.log("FraiseTimeCredits: ", address(timeCredits));

        // ── 4. FraiseNFC ──────────────────────────────────────────────────────
        nfc = new FraiseNFC(admin, address(timeCredits));
        console2.log("FraiseNFC:         ", address(nfc));

        // Grant FraiseNFC the CREDIT_SOURCE_ROLE on FraiseTimeCredits
        bytes32 creditSourceRole = keccak256("CREDIT_SOURCE_ROLE");
        timeCredits.grantRole(creditSourceRole, address(nfc));

        // ── 5. FraiseToken (UUPS proxy) ───────────────────────────────────────
        tokenImpl = new FraiseToken();
        bytes memory initData = abi.encodeCall(
            FraiseToken.initialize,
            (admin, address(timelock), minter)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(tokenImpl), initData);
        token = FraiseToken(address(proxy));
        console2.log("FraiseToken impl:  ", address(tokenImpl));
        console2.log("FraiseToken proxy: ", address(token));

        // ── 6. FraisePayments ─────────────────────────────────────────────────
        address[] memory initialTokens = new address[](1);
        initialTokens[0] = usdc;

        payments = new FraisePayments(admin, feeCollector, feeBps, initialTokens);
        console2.log("FraisePayments:    ", address(payments));

        vm.stopBroadcast();

        // ── Summary ───────────────────────────────────────────────────────────
        console2.log("\n=== Fraise Protocol Deployment ===");
        console2.log("Network:            ", block.chainid);
        console2.log("Admin (Safe):       ", admin);
        console2.log("Timelock delay (s): ", timelockDelay);
        console2.log("USDC:               ", usdc);
        console2.log("Fee:                ", feeBps, "bps");
    }
}
