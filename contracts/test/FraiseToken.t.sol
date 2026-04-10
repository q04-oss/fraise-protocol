// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BaseTest } from "./helpers/BaseTest.sol";
import { FraiseToken } from "../src/FraiseToken.sol";
import { IFraiseToken } from "../src/interfaces/IFraiseToken.sol";

contract FraiseTokenTest is BaseTest {
    FraiseToken public impl;
    FraiseToken public token; // proxy

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    function setUp() public override {
        super.setUp();

        impl = new FraiseToken();

        bytes memory initData = abi.encodeCall(
            FraiseToken.initialize,
            (admin, upgrader, minter)
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), initData);
        token = FraiseToken(address(proxy));
    }

    // ─── initialize ───────────────────────────────────────────────────────────

    function test_initialize_setsName() public view {
        assertEq(token.name(), "Fraise");
        assertEq(token.symbol(), "FRAISE");
    }

    function test_initialize_decimals() public view {
        assertEq(token.decimals(), 6);
    }

    function test_initialize_rolesGranted() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(MINTER_ROLE, minter));
        assertTrue(token.hasRole(UPGRADER_ROLE, upgrader));
    }

    function test_initialize_revertsOnZeroAdmin() public {
        FraiseToken freshImpl = new FraiseToken();
        bytes memory initData = abi.encodeCall(
            FraiseToken.initialize,
            (address(0), upgrader, minter)
        );
        vm.expectRevert(IFraiseToken.ZeroAddress.selector);
        new ERC1967Proxy(address(freshImpl), initData);
    }

    function test_initialize_revertsOnZeroUpgrader() public {
        FraiseToken freshImpl = new FraiseToken();
        bytes memory initData = abi.encodeCall(
            FraiseToken.initialize,
            (admin, address(0), minter)
        );
        vm.expectRevert(IFraiseToken.ZeroAddress.selector);
        new ERC1967Proxy(address(freshImpl), initData);
    }

    function test_initialize_revertsOnZeroMinter() public {
        FraiseToken freshImpl = new FraiseToken();
        bytes memory initData = abi.encodeCall(
            FraiseToken.initialize,
            (admin, upgrader, address(0))
        );
        vm.expectRevert(IFraiseToken.ZeroAddress.selector);
        new ERC1967Proxy(address(freshImpl), initData);
    }

    // ─── mint ─────────────────────────────────────────────────────────────────

    function test_mint_increasesSupply() public {
        vm.prank(minter);
        token.mint(alice, 1000e6);

        assertEq(token.totalSupply(), 1000e6);
        assertEq(token.balanceOf(alice), 1000e6);
    }

    function test_mint_emitsEvent() public {
        vm.prank(minter);
        vm.expectEmit(true, false, false, true);
        emit IFraiseToken.Minted(alice, 500e6);
        token.mint(alice, 500e6);
    }

    function test_mint_revertsIfNotMinter() public {
        vm.prank(alice);
        vm.expectRevert();
        token.mint(alice, 1e6);
    }

    function test_mint_revertsOnZeroAddress() public {
        vm.prank(minter);
        vm.expectRevert(IFraiseToken.ZeroAddress.selector);
        token.mint(address(0), 1e6);
    }

    function test_mint_revertsOnZeroAmount() public {
        vm.prank(minter);
        vm.expectRevert(IFraiseToken.ZeroAmount.selector);
        token.mint(alice, 0);
    }

    // ─── burn ─────────────────────────────────────────────────────────────────

    function test_burn_decreasesSupply() public {
        vm.prank(minter);
        token.mint(alice, 1000e6);

        vm.prank(minter);
        token.burn(alice, 400e6);

        assertEq(token.totalSupply(), 600e6);
        assertEq(token.balanceOf(alice), 600e6);
    }

    function test_burn_emitsEvent() public {
        vm.prank(minter);
        token.mint(alice, 1000e6);

        vm.prank(minter);
        vm.expectEmit(true, false, false, true);
        emit IFraiseToken.Burned(alice, 1000e6);
        token.burn(alice, 1000e6);
    }

    function test_burn_revertsIfNotMinter() public {
        vm.prank(minter);
        token.mint(alice, 1000e6);

        vm.prank(alice);
        vm.expectRevert();
        token.burn(alice, 1000e6);
    }

    function test_burn_revertsOnZeroAmount() public {
        vm.prank(minter);
        vm.expectRevert(IFraiseToken.ZeroAmount.selector);
        token.burn(alice, 0);
    }

    // ─── updateGoldReserve ────────────────────────────────────────────────────

    function test_updateGoldReserve_storesURI() public {
        string memory uri = "ipfs://QmGoldAttestation2026";

        vm.prank(admin);
        token.updateGoldReserve(uri);

        assertEq(token.goldReserveURI(), uri);
        assertEq(token.goldReserveTimestamp(), block.timestamp);
    }

    function test_updateGoldReserve_emitsEvent() public {
        string memory uri = "ipfs://QmGoldAttestation2026";

        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit IFraiseToken.GoldReserveUpdated(uri, block.timestamp);
        token.updateGoldReserve(uri);
    }

    function test_updateGoldReserve_revertsIfNotAdmin() public {
        vm.prank(alice);
        vm.expectRevert();
        token.updateGoldReserve("ipfs://unauthorized");
    }

    function test_goldReserveURI_emptyByDefault() public view {
        assertEq(bytes(token.goldReserveURI()).length, 0);
    }

    // ─── UUPS upgrade ─────────────────────────────────────────────────────────

    function test_upgrade_requiresUpgraderRole() public {
        FraiseToken newImpl = new FraiseToken();

        // upgrader holds UPGRADER_ROLE
        vm.prank(upgrader);
        token.upgradeToAndCall(address(newImpl), "");

        // Verify still functional after upgrade
        vm.prank(minter);
        token.mint(alice, 1e6);
        assertEq(token.balanceOf(alice), 1e6);
    }

    function test_upgrade_revertsIfNotUpgrader() public {
        FraiseToken newImpl = new FraiseToken();

        vm.prank(alice);
        vm.expectRevert();
        token.upgradeToAndCall(address(newImpl), "");
    }

    function test_upgrade_preservesStorage() public {
        vm.prank(minter);
        token.mint(alice, 999e6);

        FraiseToken newImpl = new FraiseToken();
        vm.prank(upgrader);
        token.upgradeToAndCall(address(newImpl), "");

        assertEq(token.balanceOf(alice), 999e6);
    }

    // ─── ERC-20 standard behaviour ────────────────────────────────────────────

    function test_transfer() public {
        vm.prank(minter);
        token.mint(alice, 100e6);

        vm.prank(alice);
        token.transfer(bob, 40e6);

        assertEq(token.balanceOf(alice), 60e6);
        assertEq(token.balanceOf(bob), 40e6);
    }

    function test_approve_and_transferFrom() public {
        vm.prank(minter);
        token.mint(alice, 100e6);

        vm.prank(alice);
        token.approve(bob, 50e6);

        vm.prank(bob);
        token.transferFrom(alice, bob, 50e6);

        assertEq(token.balanceOf(bob), 50e6);
    }
}
