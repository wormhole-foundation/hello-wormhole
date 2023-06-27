// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "wormhole-relayer-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-relayer-sdk/interfaces/IWormholeReceiver.sol";
import "wormhole-relayer-sdk/WormholeRelayerSDK.sol";

contract HelloWormholeProtections is Base, IWormholeReceiver {
    event GreetingReceived(string greeting, uint16 senderChain, address sender);

    uint256 constant GAS_LIMIT = 50_000;

    string public latestGreeting;

    constructor(address _wormholeRelayer) Base(_wormholeRelayer) {}

    function quoteCrossChainGreeting(uint16 targetChain) public view returns (uint256 cost) {
        (cost,) = wormholeRelayer.quoteEVMDeliveryPrice(targetChain, 0, GAS_LIMIT);
    }

    function sendCrossChainGreeting(uint16 targetChain, address targetAddress, string memory greeting) public payable {
        uint256 cost = quoteCrossChainGreeting(targetChain);
        require(msg.value == cost);
        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            targetAddress,
            abi.encode(greeting), // payload
            0, // no receiver value needed since we're just passing a message
            GAS_LIMIT
        );
    }

    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory, // additionalVaas
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    )
        public
        payable
        override
        onlyWormholeRelayer
        isRegisteredSender(sourceChain, sourceAddress)
        replayProtect(deliveryHash)
    {
        latestGreeting = abi.decode(payload, (string));

        emit GreetingReceived(latestGreeting, sourceChain, fromWormholeFormat(sourceAddress));
    }
}
