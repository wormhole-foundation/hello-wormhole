// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "wormhole-relayer-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-relayer-sdk/PayloadReceiver.sol";
import "wormhole-relayer-sdk/Utils.sol";

contract HelloWormhole is PayloadReceiver {
    event GreetingReceived(string greeting, uint16 senderChain, address sender);

    uint256 constant GAS_LIMIT = 100_000;

    IWormholeRelayer public immutable wormholeRelayer;

    string[] public greetings;

    constructor(address _wormholeRelayer) {
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
    }

    function quoteCrossChainGreeting(uint16 targetChain) public view returns (uint256 cost) {
        (cost, ) = wormholeRelayer.quoteEVMDeliveryPrice(targetChain, 0, GAS_LIMIT);
    } 

    function sendCrossChainGreeting(uint16 targetChain, address targetAddress, string memory greeting) public payable {
        uint256 cost = quoteCrossChainGreeting(targetChain);

        require(msg.value == cost, "Payment not correct");

        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            targetAddress,
            abi.encode(greeting), // payload
            0, // no receiver value needed since we're just passing a message
            GAS_LIMIT
        );
    }

    function receivePayload(bytes memory payload, address sourceAddress, uint16 sourceChain) internal override {
        require(msg.sender == address(wormholeRelayer), "Only relayer allowed");

        string memory greeting = abi.decode(payload, (string));
        greetings.push(greeting);

        emit GreetingReceived(greeting, sourceChain, sourceAddress);
    } 
}
