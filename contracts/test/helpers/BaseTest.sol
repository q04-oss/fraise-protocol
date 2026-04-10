// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Test } from "forge-std/Test.sol";

abstract contract BaseTest is Test {
    address internal admin = makeAddr("admin");
    address internal registrar = makeAddr("registrar");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal device = makeAddr("device");
    address internal feeCollector = makeAddr("feeCollector");
    address internal upgrader = makeAddr("upgrader");
    address internal minter = makeAddr("minter");

    uint256 internal registrarPk;

    function setUp() public virtual {
        // Give registrar a known private key for signature tests
        registrarPk = 0xABCD1234;
        registrar = vm.addr(registrarPk);
        vm.label(registrar, "registrar");
    }

    /// @dev Sign a message hash with a known private key (for selfRegister tests).
    function _sign(uint256 pk, bytes32 msgHash) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, msgHash);
        return abi.encodePacked(r, s, v);
    }
}
