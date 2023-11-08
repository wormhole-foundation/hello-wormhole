// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";
import "wormhole-solidity-sdk/WormholeRelayerSDK.sol";

contract HelloWormholeProtections is Base, IWormholeReceiver {
    event GreetingReceived(string greeting, uint16 senderChain, address sender);

    uint256 constant GAS_LIMIT = 50_000;

    string public latestGreeting;

    constructor(
        address _wormholeRelayer,
        address _wormhole
    ) Base(_wormholeRelayer, _wormhole) {}

    function quoteCrossChainGreeting(
        uint16 targetChain
    ) public view returns (uint256 cost) {
        (cost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            0,
            GAS_LIMIT
        );
    }

    function sendCrossChainGreeting(
        uint16 targetChain,
        address targetAddress,
        string memory greeting
    ) public payable {
        uint256 cost = quoteCrossChainGreeting(targetChain);
        require(msg.value == cost);
        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            targetAddress,
            abi.encode(greeting, msg.sender), // payload
            0, // no receiver value needed since we're just passing a message
            GAS_LIMIT
        );
    }

    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory, // additionalVaas
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 // delivery hash
    )
        public
        payable
        override
        onlyWormholeRelayer
        isRegisteredSender(sourceChain, sourceAddress)
    {
        (string memory greeting, address sender) = abi.decode(
            payload,
            (string, address)
        );
        latestGreeting = greeting;

        emit GreetingReceived(latestGreeting, sourceChain, sender);
    }
}
