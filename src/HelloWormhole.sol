// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";

contract HelloWormhole is IWormholeReceiver {
    event GreetingReceived(string greeting, uint16 senderChain, address sender);

    IWormholeRelayer public immutable wormholeRelayer;

    string public latestGreeting;

    constructor(address _wormholeRelayer) {
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
    }

    function quoteCrossChainGreeting(uint16 targetChain) public view returns (uint256 cost) {
        // Use a function on the IWormholeRelayer interface to return the msg.value needed to call sendCrossChainGreeting!
        cost = 0;
    }

    function sendCrossChainGreeting(uint16 targetChain, address targetAddress, string memory greeting) public payable {
        uint256 cost = quoteCrossChainGreeting(targetChain);
        require(msg.value == cost);
        
        // Use a function on the IWormholeRelayer interface to cause 'receiveWormholeMessages' (which is on a different blockchain!)
        // to be called in the intended way
        //
        // Test your code with 'forge test'
    }

    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory, // additionalVaas
        bytes32, // address that requested the sending of the payload
        uint16 sourceChain,
        bytes32 // deliveryHash
    ) public payable override {
        require(msg.sender == address(wormholeRelayer), "Only relayer allowed");

        (string memory greeting, address sender) = abi.decode(payload, (string, address));

        latestGreeting = greeting;

        emit GreetingReceived(greeting, sourceChain, sender);
    }
}
