// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract HelloWorld {
    event GreetingReceived(string greeting, address sender);
    
    string public latestGreeting;

    function sendGreeting(string memory greeting) public {
        emit GreetingReceived(greeting, msg.sender);
        latestGreeting = greeting;
    }
}