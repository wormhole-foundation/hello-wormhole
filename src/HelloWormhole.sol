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

    /**
     * receiveWormholeMessages should 
     * 1) update 'latestGreeting' to be the sent greeting
     * 2) cause a GreetingReceived event to be emitted
     * with the sent greeting, senderChain, and sender
     * 
     * Only 'wormholeRelayer' should be allowed to call this method
     * 
     * @param payload This will be 'abi.encode(greeting, sender)'
     * @param sourceChain This is the chain from which the payload was sent
     */
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory, // additionalVaas
        bytes32, // address that requested the sending of the payload
        uint16 sourceChain,
        bytes32 // deliveryHash
    ) public payable override {
        // implement this function!
        // run 'forge test' to test your implementation
        
    }
}