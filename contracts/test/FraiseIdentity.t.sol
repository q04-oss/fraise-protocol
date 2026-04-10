// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { BaseTest } from "./helpers/BaseTest.sol";
import { FraiseIdentity } from "../src/FraiseIdentity.sol";
import { IFraiseIdentity } from "../src/interfaces/IFraiseIdentity.sol";

contract FraiseIdentityTest is BaseTest {
    FraiseIdentity public identity;

    function setUp() public override {
        super.setUp();
        identity = new FraiseIdentity(admin, registrar);
    }

    // ─── registerIdentity ─────────────────────────────────────────────────────

    function test_registerIdentity_registrar() public {
        vm.prank(registrar);
        identity.registerIdentity(alice, "alice.fraise.box");

        assertEq(identity.getWallet("alice.fraise.box"), alice);
        assertEq(identity.getLabel(alice), "alice.fraise.box");
    }

    function test_registerIdentity_revertsIfNotRegistrar() public {
        vm.prank(alice);
        vm.expectRevert();
        identity.registerIdentity(alice, "alice.fraise.box");
    }

    function test_registerIdentity_revertsOnLabelCollision() public {
        vm.startPrank(registrar);
        identity.registerIdentity(alice, "alice.fraise.box");
        vm.expectRevert(IFraiseIdentity.LabelAlreadyTaken.selector);
        identity.registerIdentity(bob, "alice.fraise.box");
        vm.stopPrank();
    }

    function test_registerIdentity_revertsOnWalletCollision() public {
        vm.startPrank(registrar);
        identity.registerIdentity(alice, "alice.fraise.box");
        vm.expectRevert(IFraiseIdentity.WalletAlreadyRegistered.selector);
        identity.registerIdentity(alice, "alice2.fraise.box");
        vm.stopPrank();
    }

    function test_registerIdentity_revertsOnZeroAddress() public {
        vm.prank(registrar);
        vm.expectRevert(IFraiseIdentity.ZeroAddress.selector);
        identity.registerIdentity(address(0), "zero.fraise.box");
    }

    function test_registerIdentity_revertsOnEmptyLabel() public {
        vm.prank(registrar);
        vm.expectRevert(IFraiseIdentity.InvalidLabel.selector);
        identity.registerIdentity(alice, "");
    }

    // ─── selfRegister ─────────────────────────────────────────────────────────

    function test_selfRegister_validSig() public {
        bytes32 msgHash = keccak256(abi.encodePacked(alice, "alice.fraise.box"));
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(msgHash);
        bytes memory sig = _sign(registrarPk, ethHash);

        vm.prank(alice);
        identity.selfRegister("alice.fraise.box", sig);

        assertEq(identity.getWallet("alice.fraise.box"), alice);
    }

    function test_selfRegister_revertsOnBadSig() public {
        // OZ ECDSA.recover() throws ECDSAInvalidSignature for a zero-filled sig
        // before our InvalidSignature check runs — expectRevert() catches either.
        bytes memory badSig = new bytes(65);
        vm.prank(alice);
        vm.expectRevert();
        identity.selfRegister("alice.fraise.box", badSig);
    }

    // ─── revokeIdentity ───────────────────────────────────────────────────────

    function test_revokeIdentity_admin() public {
        vm.prank(registrar);
        identity.registerIdentity(alice, "alice.fraise.box");

        vm.prank(admin);
        identity.revokeIdentity(alice);

        assertEq(identity.getWallet("alice.fraise.box"), address(0));
        assertEq(bytes(identity.getLabel(alice)).length, 0);
    }

    function test_revokeIdentity_revertsIfNotRegistered() public {
        vm.prank(admin);
        vm.expectRevert(IFraiseIdentity.IdentityNotFound.selector);
        identity.revokeIdentity(alice);
    }

    function test_revokeIdentity_labelBecomesAvailableAfterRevoke() public {
        vm.prank(registrar);
        identity.registerIdentity(alice, "alice.fraise.box");

        vm.prank(admin);
        identity.revokeIdentity(alice);

        assertTrue(identity.isAvailable("alice.fraise.box"));

        // bob can now claim the label
        vm.prank(registrar);
        identity.registerIdentity(bob, "alice.fraise.box");
        assertEq(identity.getWallet("alice.fraise.box"), bob);
    }

    // ─── isAvailable ──────────────────────────────────────────────────────────

    function test_isAvailable_trueForUnregistered() public view {
        assertTrue(identity.isAvailable("nobody.fraise.box"));
    }

    function test_isAvailable_falseAfterRegistration() public {
        vm.prank(registrar);
        identity.registerIdentity(alice, "alice.fraise.box");
        assertFalse(identity.isAvailable("alice.fraise.box"));
    }
}
