// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract HelloWorld {

    event GreetingReceived(string greeting, address sender);
    
    string public latestGreeting;

    function sendGreeting(address targetAddress, string memory greeting) public {
        HelloWorld(targetAddress).receiveGreeting(greeting, msg.sender);
    }

    function receiveGreeting(string memory greeting, address sender) public {
        emit GreetingReceived(greeting, sender);
        latestGreeting = greeting;
    }
}