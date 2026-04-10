// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseTest } from "./helpers/BaseTest.sol";
import { FraiseTimeCredits } from "../src/FraiseTimeCredits.sol";
import { IFraiseTimeCredits } from "../src/interfaces/IFraiseTimeCredits.sol";

contract FraiseTimeCreditsTest is BaseTest {
    FraiseTimeCredits public tc;
    bytes32 public constant CREDIT_SOURCE_ROLE = keccak256("CREDIT_SOURCE_ROLE");

    function setUp() public override {
        super.setUp();
        tc = new FraiseTimeCredits(admin);

        // Grant device the CREDIT_SOURCE_ROLE (in production, FraiseNFC holds this)
        vm.prank(admin);
        tc.grantRole(CREDIT_SOURCE_ROLE, device);
    }

    // ─── credit ───────────────────────────────────────────────────────────────

    function test_credit_addsBalance() public {
        vm.prank(device);
        tc.credit(alice, 30 days);

        assertEq(tc.currentBalance(alice), 30 days);
    }

    function test_credit_accumulates() public {
        vm.prank(device);
        tc.credit(alice, 10 days);
        vm.prank(device);
        tc.credit(alice, 20 days);

        assertEq(tc.currentBalance(alice), 30 days);
    }

    function test_credit_revertsIfNotAuthorized() public {
        vm.prank(alice);
        vm.expectRevert();
        tc.credit(alice, 1 days);
    }

    function test_credit_revertsOnZeroAmount() public {
        vm.prank(device);
        vm.expectRevert(IFraiseTimeCredits.ZeroAmount.selector);
        tc.credit(alice, 0);
    }

    function test_credit_revertsOnZeroAddress() public {
        vm.prank(device);
        vm.expectRevert(IFraiseTimeCredits.ZeroAddress.selector);
        tc.credit(address(0), 1 days);
    }

    // ─── drain ────────────────────────────────────────────────────────────────

    function test_balance_drainsOverTime() public {
        vm.prank(device);
        tc.credit(alice, 10 days);

        // Fast-forward 3 days
        vm.warp(block.timestamp + 3 days);
        assertEq(tc.currentBalance(alice), 7 days);
    }

    function test_balance_floorsAtZero() public {
        vm.prank(device);
        tc.credit(alice, 1 days);

        vm.warp(block.timestamp + 2 days);
        assertEq(tc.currentBalance(alice), 0);
    }

    function test_balance_zeroForFreshAccount() public view {
        assertEq(tc.currentBalance(alice), 0);
    }

    // ─── lifetimeCredits ──────────────────────────────────────────────────────

    function test_lifetimeCredits_neverDecreases() public {
        vm.prank(device);
        tc.credit(alice, 30 days);

        vm.warp(block.timestamp + 60 days);

        assertEq(tc.currentBalance(alice), 0);
        assertEq(tc.lifetimeCredits(alice), 30 days);
    }

    // ─── getTier ──────────────────────────────────────────────────────────────

    function test_getTier_none() public view {
        assertEq(uint8(tc.getTier(alice)), uint8(IFraiseTimeCredits.Tier.None));
    }

    function test_getTier_standard() public {
        vm.prank(device);
        tc.credit(alice, 1 days);
        assertEq(uint8(tc.getTier(alice)), uint8(IFraiseTimeCredits.Tier.Standard));
    }

    function test_getTier_reserve() public {
        vm.prank(device);
        tc.credit(alice, 30 days);
        assertEq(uint8(tc.getTier(alice)), uint8(IFraiseTimeCredits.Tier.Reserve));
    }

    function test_getTier_estate() public {
        vm.prank(device);
        tc.credit(alice, 75 days);
        assertEq(uint8(tc.getTier(alice)), uint8(IFraiseTimeCredits.Tier.Estate));
    }

    function test_getTier_degradesAfterDrain() public {
        vm.prank(device);
        tc.credit(alice, 30 days); // Reserve

        vm.warp(block.timestamp + 29 days + 1); // < 1 day remaining
        assertEq(uint8(tc.getTier(alice)), uint8(IFraiseTimeCredits.Tier.None));
    }
}
