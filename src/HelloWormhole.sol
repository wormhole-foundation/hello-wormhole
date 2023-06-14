// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "wormhole-relayer-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-relayer-sdk/interfaces/IWormholeReceiver.sol";

contract HelloWormhole is IWormholeReceiver {
    event GreetingReceived(string greeting, uint16 senderChain, address sender);

    uint256 constant GAS_LIMIT = 50_000;

    IWormholeRelayer public immutable wormholeRelayer;

    string[] public greetings;

    constructor(address _wormholeRelayer) {
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
    }

    /**
     * @notice Returns the cost (in wei) of a greeting
     */
    function quoteCrossChainGreeting(
        uint16 targetChain
    ) public view returns (uint256 cost) {
        // Cost of requesting a message to be sent to
        // chain 'targetChain' with a gasLimit of 'GAS_LIMIT'
        (cost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            0,
            GAS_LIMIT
        );
    }

    /**
     * @notice Updates the list of 'greetings' 
     * and emits a 'GreetingReceived' event with 'greeting'
     * on the HelloWormhole contract at 
     * chain 'targetChain' and address 'targetAddress'
     */
    function sendCrossChainGreeting(
        uint16 targetChain,
        address targetAddress,
        string memory greeting
    ) public payable {
        uint256 cost = quoteCrossChainGreeting(targetChain);

        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            targetAddress,
            abi.encode(greeting), // payload
            0, // no receiver value needed since we're just passing a message
            GAS_LIMIT
        );

        if (msg.value > cost) {
            (bool success, ) = msg.sender.call{value: msg.value - cost}("");
            require(success, "Returning excess funds failed");
        }
    }

    /**
     * @notice Endpoint that the Wormhole Relayer contract will call
     * to deliver the greeting
     */
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory, // additionalVaas
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 // deliveryHash
    ) public payable override {
        require(msg.sender == address(wormholeRelayer), "Only relayer allowed");

        string memory greeting = abi.decode(payload, (string));
        greetings.push(greeting);

        emit GreetingReceived(
            greeting,
            sourceChain,
            fromWormholeFormat(sourceAddress)
        );
    }
}

function fromWormholeFormat(bytes32 whFormatAddress) pure returns (address) {
    if (uint256(whFormatAddress) >> 160 != 0)
        revert NotAnEvmAddress(whFormatAddress);
    return address(uint160(uint256(whFormatAddress)));
}
  
  
        
   