// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../src/extensions/HelloWormholeRefunds.sol";

import "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";

contract HelloWormholeRefundsTest is WormholeRelayerBasicTest {
    event GreetingReceived(string greeting, uint16 senderChain, address sender);

    HelloWormholeRefunds helloSource;
    HelloWormholeRefunds helloTarget;

    function setUpSource() public override {
        helloSource = new HelloWormholeRefunds(address(relayerSource));
    }

    function setUpTarget() public override {
        helloTarget = new HelloWormholeRefunds(address(relayerTarget));
    }

    function testGreetingWithRefund() public {
        uint256 cost = helloSource.quoteCrossChainGreeting(targetChain);
        uint256 refundPerUnitGasUnused = helloSource.quoteCrossChainGreetingRefundPerUnitGasUnused(targetChain);

        vm.recordLogs();

        vm.selectFork(targetFork);
        address payable refundAddress = payable(0x1234567890123456789012345678901234567890);
        vm.deal(refundAddress, 0);

        vm.selectFork(sourceFork);

        helloSource.sendCrossChainGreeting{value: cost}(targetChain, address(helloTarget), "Hello Wormhole!", targetChain, refundAddress);

        performDelivery();

        vm.selectFork(targetFork);
        assertEq(helloTarget.latestGreeting(), "Hello Wormhole!");
        
        // received refund
        assertTrue(refundAddress.balance > refundPerUnitGasUnused * 450000); // at least 450000 units of gas were unused (out of the incredibly large 500000 gas limit))
        assertTrue(refundAddress.balance <= refundPerUnitGasUnused * 500000); 
    }

    function testGreetingWithCrossChainRefund() public {
        uint256 cost = helloSource.quoteCrossChainGreeting(targetChain);

        vm.recordLogs();

        address payable refundAddress = payable(0x1234567890123456789012345678901234567890);
        vm.deal(refundAddress, 0);

        helloSource.sendCrossChainGreeting{value: cost}(targetChain, address(helloTarget), "Hello Wormhole!", sourceChain, refundAddress);

        performDelivery();

        vm.selectFork(targetFork);
        assertEq(helloTarget.latestGreeting(), "Hello Wormhole!");

        performDelivery();

        // received refund
        vm.selectFork(sourceFork);
        assertTrue(refundAddress.balance > 0); // at least 450000 units of gas were unused (out of the incredibly large 500000 gas limit))
    }
}
