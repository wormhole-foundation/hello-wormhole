// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";

contract HelloWormholeRefunds is IWormholeReceiver {
    event GreetingReceived(string greeting, uint16 senderChain, address sender);

    // Way too much gas, for purpose of illustrating refund
    uint256 constant GAS_LIMIT = 500_000;

    IWormholeRelayer public immutable wormholeRelayer;

    string public latestGreeting;

    constructor(address _wormholeRelayer) {
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
    }

    function quoteCrossChainGreeting(uint16 targetChain) public view returns (uint256 cost) {
        (cost,) = wormholeRelayer.quoteEVMDeliveryPrice(targetChain, 0, GAS_LIMIT);
    }

    function quoteCrossChainGreetingRefundPerUnitGasUnused(uint16 targetChain) public view returns (uint256 refundPerUnitGasUnused) {
        (, refundPerUnitGasUnused) = wormholeRelayer.quoteEVMDeliveryPrice(targetChain, 0, GAS_LIMIT);
    }

    function sendCrossChainGreeting(
        uint16 targetChain,
        address targetAddress,
        string memory greeting,
        uint16 refundChain,
        address refundAddress
    ) public payable {
        uint256 cost = quoteCrossChainGreeting(targetChain);
        require(msg.value == cost);
        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            targetAddress,
            abi.encode(greeting, msg.sender), // payload
            0, // no receiver value needed since we're just passing a message
            GAS_LIMIT,
            refundChain, 
            refundAddress 
        );
    }

    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory, // additionalVaas
        bytes32, // address that called 'sendPayloadToEvm' (HelloWormholeRefunds contract address)
        uint16 sourceChain,
        bytes32 // deliveryHash
    ) public payable override {
        require(msg.sender == address(wormholeRelayer), "Only relayer allowed");

        (string memory greeting, address sender) = abi.decode(payload, (string, address));
        latestGreeting = greeting;

        emit GreetingReceived(latestGreeting, sourceChain, sender);
    }
}
