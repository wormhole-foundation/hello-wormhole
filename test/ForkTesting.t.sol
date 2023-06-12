// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/HelloWormhole.sol";
import "../src/interfaces/IWormholeRelayer.sol";

import "./mocks/WormholeRelayerForkTestingBase.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

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
        uint256 cost = helloSource.quoteCrossChainGreeting(targetChain);

        vm.recordLogs();
        helloSource.sendCrossChainGreeting{value: cost}(
            targetChain,
            address(helloTarget),
            "Hello Wormhole!"
        );

        performDelivery(1);

        vm.selectFork(targetFork);
        assertEq(helloTarget.greetings(0), "Hello Wormhole!");
    }
}
