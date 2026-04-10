// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseTest } from "./helpers/BaseTest.sol";
import { FraiseNFC } from "../src/FraiseNFC.sol";
import { FraiseTimeCredits } from "../src/FraiseTimeCredits.sol";
import { IFraiseNFC } from "../src/interfaces/IFraiseNFC.sol";

contract FraiseNFCTest is BaseTest {
    FraiseNFC public nfc;
    FraiseTimeCredits public tc;

    bytes32 public constant CREDIT_SOURCE_ROLE = keccak256("CREDIT_SOURCE_ROLE");
    bytes32 public constant DEVICE_ROLE = keccak256("DEVICE_ROLE");

    bytes32 internal tagId = keccak256("tag-uid-001");
    bytes32 internal varietyId = keccak256("gariguette");
    bytes32 internal farmId = keccak256("ferme-du-soleil");

    function setUp() public override {
        super.setUp();
        tc = new FraiseTimeCredits(admin);
        nfc = new FraiseNFC(admin, address(tc));

        // Grant FraiseNFC the CREDIT_SOURCE_ROLE on FraiseTimeCredits
        vm.prank(admin);
        tc.grantRole(CREDIT_SOURCE_ROLE, address(nfc));

        // Grant device the DEVICE_ROLE
        vm.prank(admin);
        nfc.addDevice(device);
    }

    // ─── recordScan ───────────────────────────────────────────────────────────

    function test_recordScan_emitsEvent() public {
        vm.prank(device);
        vm.expectEmit(true, true, true, true);
        emit IFraiseNFC.NFCScanRecorded(1, tagId, varietyId, farmId, alice, block.timestamp);
        nfc.recordScan(tagId, varietyId, farmId, alice);
    }

    function test_recordScan_incrementsScanId() public {
        vm.startPrank(device);
        uint256 id1 = nfc.recordScan(tagId, varietyId, farmId, alice);
        bytes32 tagId2 = keccak256("tag-002");
        uint256 id2 = nfc.recordScan(tagId2, varietyId, farmId, alice);
        vm.stopPrank();

        assertEq(id1, 1);
        assertEq(id2, 2);
    }

    function test_recordScan_creditsTimeCredits() public {
        vm.prank(device);
        nfc.recordScan(tagId, varietyId, farmId, alice);

        assertEq(tc.currentBalance(alice), nfc.scanCreditSeconds());
    }

    function test_recordScan_revertsIfNotDevice() public {
        vm.prank(alice);
        vm.expectRevert();
        nfc.recordScan(tagId, varietyId, farmId, alice);
    }

    function test_recordScan_revertsOnZeroBeneficiary() public {
        vm.prank(device);
        vm.expectRevert(IFraiseNFC.ZeroAddress.selector);
        nfc.recordScan(tagId, varietyId, farmId, address(0));
    }

    // ─── Anti-replay ──────────────────────────────────────────────────────────

    function test_recordScan_revertsOnCooldown() public {
        vm.prank(device);
        nfc.recordScan(tagId, varietyId, farmId, alice);

        vm.prank(device);
        vm.expectRevert();
        nfc.recordScan(tagId, varietyId, farmId, alice);
    }

    function test_recordScan_allowsAfterCooldown() public {
        vm.prank(device);
        nfc.recordScan(tagId, varietyId, farmId, alice);

        vm.warp(block.timestamp + nfc.MIN_SCAN_INTERVAL());

        vm.prank(device);
        uint256 id = nfc.recordScan(tagId, varietyId, farmId, alice);
        assertEq(id, 2);
    }

    // ─── Rate limiting ────────────────────────────────────────────────────────

    function test_recordScan_revertsOnRateLimit() public {
        vm.startPrank(device);
        for (uint256 i = 0; i < nfc.MAX_SCANS_PER_HOUR(); i++) {
            bytes32 uid = keccak256(abi.encodePacked("tag", i));
            nfc.recordScan(uid, varietyId, farmId, alice);
        }
        bytes32 overLimit = keccak256("overlimit");
        vm.expectRevert(IFraiseNFC.DeviceRateLimitExceeded.selector);
        nfc.recordScan(overLimit, varietyId, farmId, alice);
        vm.stopPrank();
    }

    // ─── Pause ────────────────────────────────────────────────────────────────

    function test_pause_blocksScans() public {
        vm.prank(admin);
        nfc.pause();

        vm.prank(device);
        vm.expectRevert();
        nfc.recordScan(tagId, varietyId, farmId, alice);
    }

    function test_unpause_restoresScans() public {
        vm.prank(admin);
        nfc.pause();
        vm.prank(admin);
        nfc.unpause();

        vm.prank(device);
        uint256 id = nfc.recordScan(tagId, varietyId, farmId, alice);
        assertEq(id, 1);
    }

    // ─── Device management ────────────────────────────────────────────────────

    function test_revokeDevice_preventsScans() public {
        vm.prank(admin);
        nfc.revokeDevice(device);

        vm.prank(device);
        vm.expectRevert();
        nfc.recordScan(tagId, varietyId, farmId, alice);
    }

    // ─── View ─────────────────────────────────────────────────────────────────

    function test_totalScans() public {
        assertEq(nfc.totalScans(), 0);
        vm.prank(device);
        nfc.recordScan(tagId, varietyId, farmId, alice);
        assertEq(nfc.totalScans(), 1);
    }

    function test_lastScanAt() public {
        vm.prank(device);
        nfc.recordScan(tagId, varietyId, farmId, alice);
        assertEq(nfc.lastScanAt(tagId), block.timestamp);
    }
}
