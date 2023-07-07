// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/HelloWormhole.sol";

import "wormhole-solidity-sdk/testing/WormholeRelayerTest.sol";

contract HelloWormholeTest is WormholeRelayerTest {
    event GreetingReceived(string greeting, uint16 senderChain, address sender);

    HelloWormhole helloSource;
    HelloWormhole helloTarget;

    function setUpSource() public override {
        helloSource = new HelloWormhole(address(relayerSource));
    }

    function setUpTarget() public override {
        helloTarget = new HelloWormhole(address(relayerTarget));
    }

    function testGreeting() public {

        bytes32 sourceAddress = toWormholeFormat(address(helloSource));

        vm.selectFork(targetFork);

        vm.expectEmit();

        emit GreetingReceived("Hello Wormhole!", sourceChain, address(0x0));
        vm.prank(address(relayerTarget));
        helloTarget.receiveWormholeMessages(
            abi.encode("Hello Wormhole!"),
            new bytes[](0),
            sourceAddress,
            sourceChain,
            keccak256("Arbitrary Delivery Hash")
        );

        assertEq(helloTarget.latestGreeting(), "Hello Wormhole!");
    }
}
