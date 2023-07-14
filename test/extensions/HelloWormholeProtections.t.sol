// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../src/extensions/HelloWormholeProtections.sol";

import "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";

contract HelloWormholeProtectionsTest is WormholeRelayerBasicTest {
    event GreetingReceived(string greeting, uint16 senderChain, address sender);

    HelloWormholeProtections helloSource;
    HelloWormholeProtections helloTarget;

    function setUpSource() public override {
        helloSource = new HelloWormholeProtections(address(relayerSource), address(wormholeSource));
    }

    function setUpTarget() public override {
        helloTarget = new HelloWormholeProtections(address(relayerTarget), address(wormholeTarget));
        helloTarget.setRegisteredSender(sourceChain, toWormholeFormat(address(helloSource)));
    }

    function testGreeting() public {
        uint256 cost = helloSource.quoteCrossChainGreeting(targetChain);

        vm.recordLogs();

        helloSource.sendCrossChainGreeting{value: cost}(targetChain, address(helloTarget), "Hello Wormhole!");

        performDelivery();

        vm.selectFork(targetFork);
        assertEq(helloTarget.latestGreeting(), "Hello Wormhole!");
    }

    function testGreetingFromWrongSender() public {
        HelloWormholeProtections fakeHelloSource = new HelloWormholeProtections(address(relayerSource), address(wormholeSource));
        uint256 cost = fakeHelloSource.quoteCrossChainGreeting(targetChain);

        vm.recordLogs();

        fakeHelloSource.sendCrossChainGreeting{value: cost}(
            targetChain, address(helloTarget), "Hello Wormhole from Fake Source!"
        );

        performDelivery();

        vm.selectFork(targetFork);
        // Message should not have gone through
        assertEq(helloTarget.latestGreeting(), "");
    }
}
