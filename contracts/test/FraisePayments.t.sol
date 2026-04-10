// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseTest } from "./helpers/BaseTest.sol";
import { MockERC20 } from "./helpers/MockERC20.sol";
import { FraisePayments } from "../src/FraisePayments.sol";
import { IFraisePayments } from "../src/interfaces/IFraisePayments.sol";

contract FraisePaymentsTest is BaseTest {
    FraisePayments public payments;
    MockERC20 public usdc;
    MockERC20 public fraise;

    bytes32 internal orderRef = keccak256("order-uuid-001");

    uint256 internal constant FEE_BPS = 200; // 2%
    uint256 internal constant AMOUNT = 100e6; // 100 USDC

    function setUp() public override {
        super.setUp();

        usdc = new MockERC20("USD Coin", "USDC", 6);
        fraise = new MockERC20("Fraise", "FRAISE", 6);

        address[] memory tokens = new address[](1);
        tokens[0] = address(usdc);

        payments = new FraisePayments(admin, feeCollector, FEE_BPS, tokens);

        // Mint and approve for alice
        usdc.mint(alice, 1000e6);
        vm.prank(alice);
        usdc.approve(address(payments), type(uint256).max);
    }

    // ─── constructor ──────────────────────────────────────────────────────────

    function test_constructor_setsOwner() public view {
        assertEq(payments.owner(), admin);
    }

    function test_constructor_setsFee() public view {
        assertEq(payments.feeBps(), FEE_BPS);
    }

    function test_constructor_setsCollector() public view {
        assertEq(payments.feeCollector(), feeCollector);
    }

    function test_constructor_whitelistsInitialToken() public view {
        assertTrue(payments.isSupported(address(usdc)));
    }

    function test_constructor_revertsOnZeroOwner() public {
        // OZ Ownable(address(0)) reverts with OwnableInvalidOwner before our
        // ZeroAddress check — expectRevert() catches either path.
        address[] memory tokens = new address[](0);
        vm.expectRevert();
        new FraisePayments(address(0), feeCollector, FEE_BPS, tokens);
    }

    function test_constructor_revertsOnZeroCollector() public {
        address[] memory tokens = new address[](0);
        vm.expectRevert(IFraisePayments.ZeroAddress.selector);
        new FraisePayments(admin, address(0), FEE_BPS, tokens);
    }

    function test_constructor_revertsOnFeeTooHigh() public {
        address[] memory tokens = new address[](0);
        vm.expectRevert(IFraisePayments.FeeTooHigh.selector);
        new FraisePayments(admin, feeCollector, 1001, tokens);
    }

    // ─── pay ──────────────────────────────────────────────────────────────────

    function test_pay_transfersNetToRecipient() public {
        vm.prank(alice);
        payments.pay(address(usdc), AMOUNT, bob, orderRef);

        uint256 expectedFee = (AMOUNT * FEE_BPS) / 10_000; // 2 USDC
        uint256 expectedNet = AMOUNT - expectedFee;         // 98 USDC

        assertEq(usdc.balanceOf(bob), expectedNet);
    }

    function test_pay_transfersFeeToCollector() public {
        vm.prank(alice);
        payments.pay(address(usdc), AMOUNT, bob, orderRef);

        uint256 expectedFee = (AMOUNT * FEE_BPS) / 10_000;
        assertEq(usdc.balanceOf(feeCollector), expectedFee);
    }

    function test_pay_emitsEvent() public {
        uint256 expectedFee = (AMOUNT * FEE_BPS) / 10_000;

        vm.prank(alice);
        vm.expectEmit(true, true, true, true);
        emit IFraisePayments.PaymentMade(orderRef, alice, bob, address(usdc), AMOUNT, expectedFee);
        payments.pay(address(usdc), AMOUNT, bob, orderRef);
    }

    function test_pay_zeroFee_fullAmountToRecipient() public {
        vm.prank(admin);
        payments.setFeeBps(0);

        vm.prank(alice);
        payments.pay(address(usdc), AMOUNT, bob, orderRef);

        assertEq(usdc.balanceOf(bob), AMOUNT);
        assertEq(usdc.balanceOf(feeCollector), 0);
    }

    function test_pay_revertsOnUnsupportedToken() public {
        vm.prank(alice);
        vm.expectRevert(IFraisePayments.TokenNotSupported.selector);
        payments.pay(address(fraise), AMOUNT, bob, orderRef);
    }

    function test_pay_revertsOnZeroAmount() public {
        vm.prank(alice);
        vm.expectRevert(IFraisePayments.ZeroAmount.selector);
        payments.pay(address(usdc), 0, bob, orderRef);
    }

    function test_pay_revertsOnZeroRecipient() public {
        vm.prank(alice);
        vm.expectRevert(IFraisePayments.ZeroAddress.selector);
        payments.pay(address(usdc), AMOUNT, address(0), orderRef);
    }

    function test_pay_paysFullBalanceOut() public {
        vm.prank(alice);
        payments.pay(address(usdc), AMOUNT, bob, orderRef);

        // Contract should hold nothing after pay (all routed out)
        assertEq(usdc.balanceOf(address(payments)), 0);
    }

    // ─── addPaymentToken ──────────────────────────────────────────────────────

    function test_addPaymentToken_addsToken() public {
        vm.prank(admin);
        payments.addPaymentToken(address(fraise));

        assertTrue(payments.isSupported(address(fraise)));
    }

    function test_addPaymentToken_emitsEvent() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit IFraisePayments.PaymentTokenAdded(address(fraise));
        payments.addPaymentToken(address(fraise));
    }

    function test_addPaymentToken_idempotent() public {
        vm.prank(admin);
        payments.addPaymentToken(address(fraise));

        // Second add should not revert and should not duplicate list entry
        vm.prank(admin);
        payments.addPaymentToken(address(fraise));

        assertEq(payments.supportedTokens().length, 2); // usdc + fraise (once)
    }

    function test_addPaymentToken_revertsIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        payments.addPaymentToken(address(fraise));
    }

    function test_addPaymentToken_revertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(IFraisePayments.ZeroAddress.selector);
        payments.addPaymentToken(address(0));
    }

    // ─── removePaymentToken ───────────────────────────────────────────────────

    function test_removePaymentToken_removesToken() public {
        vm.prank(admin);
        payments.removePaymentToken(address(usdc));

        assertFalse(payments.isSupported(address(usdc)));
    }

    function test_removePaymentToken_emitsEvent() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit IFraisePayments.PaymentTokenRemoved(address(usdc));
        payments.removePaymentToken(address(usdc));
    }

    function test_removePaymentToken_revertsIfNotSupported() public {
        vm.prank(admin);
        vm.expectRevert(IFraisePayments.TokenNotSupported.selector);
        payments.removePaymentToken(address(fraise));
    }

    function test_removePaymentToken_revertsIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        payments.removePaymentToken(address(usdc));
    }

    function test_removePaymentToken_blocksSubsequentPay() public {
        vm.prank(admin);
        payments.removePaymentToken(address(usdc));

        vm.prank(alice);
        vm.expectRevert(IFraisePayments.TokenNotSupported.selector);
        payments.pay(address(usdc), AMOUNT, bob, orderRef);
    }

    // ─── setFeeBps ────────────────────────────────────────────────────────────

    function test_setFeeBps_updatesFee() public {
        vm.prank(admin);
        payments.setFeeBps(500);

        assertEq(payments.feeBps(), 500);
    }

    function test_setFeeBps_emitsEvent() public {
        vm.prank(admin);
        vm.expectEmit(false, false, false, true);
        emit IFraisePayments.FeeUpdated(500);
        payments.setFeeBps(500);
    }

    function test_setFeeBps_revertsIfTooHigh() public {
        vm.prank(admin);
        vm.expectRevert(IFraisePayments.FeeTooHigh.selector);
        payments.setFeeBps(1001);
    }

    function test_setFeeBps_allowsMax() public {
        vm.prank(admin);
        payments.setFeeBps(1000); // 10% — max allowed
        assertEq(payments.feeBps(), 1000);
    }

    function test_setFeeBps_revertsIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        payments.setFeeBps(100);
    }

    // ─── setFeeCollector ──────────────────────────────────────────────────────

    function test_setFeeCollector_updatesCollector() public {
        vm.prank(admin);
        payments.setFeeCollector(alice);

        assertEq(payments.feeCollector(), alice);
    }

    function test_setFeeCollector_emitsEvent() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, false);
        emit IFraisePayments.FeeCollectorUpdated(alice);
        payments.setFeeCollector(alice);
    }

    function test_setFeeCollector_revertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(IFraisePayments.ZeroAddress.selector);
        payments.setFeeCollector(address(0));
    }

    function test_setFeeCollector_revertsIfNotOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        payments.setFeeCollector(alice);
    }

    // ─── supportedTokens ──────────────────────────────────────────────────────

    function test_supportedTokens_returnsAll() public {
        vm.prank(admin);
        payments.addPaymentToken(address(fraise));

        address[] memory tokens = payments.supportedTokens();
        assertEq(tokens.length, 2);
    }

    // ─── Ownable2Step ─────────────────────────────────────────────────────────

    function test_transferOwnership_requiresAcceptance() public {
        vm.prank(admin);
        payments.transferOwnership(alice);

        // Ownership not yet transferred — still admin
        assertEq(payments.owner(), admin);

        vm.prank(alice);
        payments.acceptOwnership();
        assertEq(payments.owner(), alice);
    }
}
