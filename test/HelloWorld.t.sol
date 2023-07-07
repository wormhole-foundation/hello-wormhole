// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/HelloWorld.sol";
import "forge-std/Test.sol";

contract HelloWorldTest is Test {
    event GreetingReceived(string greeting, uint16 senderChain, address sender);

    HelloWorld helloSource;
    HelloWorld helloTarget;

    function setUp() public {
        helloSource = new HelloWorld();
        helloTarget = new HelloWorld();
    }

    function testGreeting() public {
        helloSource.sendGreeting(address(helloTarget), "Hello World!");
        assertEq(helloTarget.latestGreeting(), "Hello World!");
    }
}