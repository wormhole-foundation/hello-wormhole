// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../src/extensions/HelloWormholeConfirmation.sol";

import "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";

contract HelloWormholeConfirmationTest is WormholeRelayerBasicTest {
    event GreetingReceived(string greeting, uint16 senderChain, address sender);

    HelloWormholeConfirmation helloSource;
    HelloWormholeConfirmation helloTarget;

    function setUpSource() public override {
        helloSource = new HelloWormholeConfirmation(address(relayerSource), address(wormholeSource));
    }

    function setUpTarget() public override {
        helloTarget = new HelloWormholeConfirmation(address(relayerTarget), address(wormholeTarget));
    }

    function performRegistrations() public {
        vm.selectFork(targetFork);
        helloTarget.setRegisteredSender(sourceChain, toWormholeFormat(address(helloSource)));

        vm.selectFork(sourceFork);
        helloSource.setRegisteredSender(targetChain, toWormholeFormat(address(helloTarget)));
    }

    function testGreeting() public {

        performRegistrations();

        // Front-end calculation for how much receiver value to request the greeting with
        // to ensure a confirmation is able to come back!
        vm.selectFork(targetFork);
        // We bake in a 10% buffer to account for the possibility of a price change after the initial delivery but before the return delivery
        uint256 receiverValueForConfirmation = helloTarget.quoteConfirmation(sourceChain) * 11 / 10; 
        vm.selectFork(sourceFork);
        // end front-end calculation

        uint256 cost = helloSource.quoteCrossChainGreeting(targetChain, receiverValueForConfirmation);

        vm.recordLogs();

        helloSource.sendCrossChainGreeting{value: cost}(targetChain, address(helloTarget), "Hello Wormhole!", receiverValueForConfirmation);

        performDelivery();

        vm.selectFork(targetFork);
        assertEq(helloTarget.latestGreeting(), "Hello Wormhole!");

        performDelivery();

        vm.selectFork(sourceFork);
        assertEq(helloSource.latestConfirmedSentGreeting(), "Hello Wormhole!");
    }
}
