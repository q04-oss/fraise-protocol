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
import { MockERC20 } from "../test/helpers/MockERC20.sol";

/// @title DeploySepolia
/// @notice Testnet deployment on Optimism Sepolia.
///
/// Differences from production Deploy.s.sol:
///   - Deploys a MockERC20 as "USDC" (no real USDC on testnet)
///   - TimelockController uses a 60-second delay for rapid iteration
///   - Deployer address is used for admin/registrar/minter/feeCollector
///
/// Run:
///   forge script contracts/script/DeploySepolia.s.sol \
///     --rpc-url $OP_SEPOLIA_RPC_URL \
///     --broadcast \
///     --verify \
///     --etherscan-api-key $OP_ETHERSCAN_KEY
contract DeploySepolia is Script {
    address private _deployer;

    function run() external {
        uint256 deployerPk = vm.envUint("PRIVATE_KEY");
        _deployer = vm.addr(deployerPk);

        vm.startBroadcast(deployerPk);

        _deployAll();

        vm.stopBroadcast();
    }

    function _deployAll() internal {
        address dep = _deployer;

        // ── Mock USDC ─────────────────────────────────────────────────────────
        MockERC20 mockUsdc = new MockERC20("USD Coin (Test)", "USDC", 6);
        mockUsdc.mint(dep, 1_000_000e6);
        console2.log("MockUSDC:          ", address(mockUsdc));

        // ── TimelockController (60s delay for testnet) ────────────────────────
        _deployTimelock(dep);

        // ── Protocol contracts ────────────────────────────────────────────────
        FraiseIdentity identity = new FraiseIdentity(dep, dep);
        console2.log("FraiseIdentity:    ", address(identity));

        FraiseTimeCredits timeCredits = new FraiseTimeCredits(dep);
        console2.log("FraiseTimeCredits: ", address(timeCredits));

        FraiseNFC nfc = new FraiseNFC(dep, address(timeCredits));
        console2.log("FraiseNFC:         ", address(nfc));
        timeCredits.grantRole(keccak256("CREDIT_SOURCE_ROLE"), address(nfc));

        // ── FraiseToken (UUPS proxy) ──────────────────────────────────────────
        _deployToken(dep);

        // ── FraisePayments ────────────────────────────────────────────────────
        address[] memory initialTokens = new address[](1);
        initialTokens[0] = address(mockUsdc);
        FraisePayments payments = new FraisePayments(dep, dep, 200, initialTokens);
        console2.log("FraisePayments:    ", address(payments));

        console2.log("Chain ID:           ", block.chainid);
    }

    function _deployTimelock(address dep) internal returns (address) {
        address[] memory proposers = new address[](1);
        proposers[0] = dep;
        address[] memory executors = new address[](1);
        executors[0] = dep;
        TimelockController tl = new TimelockController(60, proposers, executors, address(0));
        console2.log("TimelockController:", address(tl));
        return address(tl);
    }

    function _deployToken(address dep) internal returns (address proxy_) {
        FraiseToken impl = new FraiseToken();
        console2.log("FraiseToken impl:  ", address(impl));
        bytes memory initData = abi.encodeCall(FraiseToken.initialize, (dep, dep, dep));
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        console2.log("FraiseToken proxy: ", address(proxy));
        return address(proxy);
    }
}
