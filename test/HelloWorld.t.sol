// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/HelloWorld.sol";
import "forge-std/Test.sol";

contract HelloWorldTest is Test {
    event GreetingReceived(string greeting, uint16 senderChain, address sender);

    HelloWorld helloWorld;

    function setUp() public {
        helloWorld = new HelloWorld();
    }

    function testGreeting() public {
        helloWorld.sendGreeting("Hello World!");
        assertEq(helloWorld.latestGreeting(), "Hello World!");
    }
}