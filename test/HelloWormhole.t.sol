// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/HelloWormhole.sol";
import "./MockWormholeRelayer.sol";
import "../src/interfaces/IWormholeRelayer.sol";

contract HelloWormholeTest is Test {
    event GreetingReceived(string greeting, uint16 senderChain, address sender);
    IWormholeRelayer relayer;
    MockWormholeRelayer _mockRelayer;

    HelloWormhole helloA;
    HelloWormhole helloB;

    uint16 constant targetChain = 4;

    function setUp() public {
        // set up Mock Wormhole Relayer
        _mockRelayer = new MockWormholeRelayer();
        address _relayer = address(_mockRelayer);
        payable(_relayer).transfer(100e18);
        relayer = IWormholeRelayer(_relayer);

        // set up HelloWormhole contracts
        helloA = new HelloWormhole(_relayer);
        helloB = new HelloWormhole(_relayer);
    }

    function testGreeting() public {
        uint256 cost = helloA.quoteGreeting(targetChain);

        helloA.sendGreeting{value: cost}(
            targetChain,
            address(helloB),
            "Hello Wormhole!"
        );

        vm.expectEmit();
        emit GreetingReceived(
            "Hello Wormhole!",
            _mockRelayer.chainId(),
            address(helloA)
        );
        _mockRelayer.performRecordedDeliveries();

        assertEq(helloB.greetings(0), "Hello Wormhole!");
    }

    receive() external payable {}
}
