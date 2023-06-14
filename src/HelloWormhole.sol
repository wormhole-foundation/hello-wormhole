// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "wormhole-relayer-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-relayer-sdk/interfaces/IWormholeReceiver.sol";

contract HelloWormhole is IWormholeReceiver {
    event GreetingReceived(string greeting, uint16 senderChain, address sender);

    // The maximum gas we're willing to pay to relay a message.
    // Note: In this case we're hardcoding a gas limit, in a production
    // level application some logic around the max gas the contract
    // is willing to pay is likely warranted.
    uint256 constant GAS_LIMIT = 50_000;

    // The interface for the contract that will handle relaying
    // our message across chains
    IWormholeRelayer public immutable wormholeRelayer;

    string[] public greetings;

    constructor(address _wormholeRelayer) {
        // setup the relayer we're using
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
    }

    /**
     * @notice Returns the price to request a relay to chain `targetChain`, using the default delivery provider
     *
     * @param targetChain in Wormhole Chain ID format
     * @return cost Price, in units of current chain currency, that the delivery provider charges to perform the relay
     */
    function quoteCrossChainGreeting(
        uint16 targetChain
    ) public view returns (uint256 cost) {
        (cost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain, // Wormhole Chain ID
            0, // value we're sending in the message (added to the returned cost)
            GAS_LIMIT // The maximum gas we're willing to cover
        );
    }

    /**
     * @notice Sends the `greeting` message to the target chain and address by invoking the relayer and covering the gas
     * costs estimated by the relayer.
     *
     * @param targetChain in Wormhole Chain ID format
     * @param targetAddress the address of the contract on the target chain the message should be relayed to
     * @param greeting the message we'd like to relay
     */
    function sendCrossChainGreeting(
        uint16 targetChain,
        address targetAddress,
        string memory greeting
    ) public payable {
        // request a quote for the gas required to deliver the message
        // on the target chain
        uint256 cost = quoteCrossChainGreeting(targetChain);

        // If the caller did not pass enough value, fail the transaction
        // otherwise the value will come from the contract's balance
        require(msg.value >= cost, "Not enough value was passed.");

        // Note: for simplicity, we're skipping a check
        //  on the size of the greeting passed here

        // call the relayer contract, passing enough value to cover
        // the cost of gas on delivery of the message
        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain, // Wormhole Chain ID on which to deliver the message
            targetAddress, // Intended recipient of the message (contract address on target chain)
            abi.encode(greeting), // payload
            0, // no receiver value needed since we're just passing a message
            GAS_LIMIT // Maximum
        );

        // If the caller passed more value than is used to cover the cross chain call,
        // refund them the rest of the value balance
        if (msg.value > cost) {
            (bool success, ) = msg.sender.call{value: msg.value - cost}("");
            require(success, "Returning excess funds failed");
        }
    }

    /**
     * @notice Receives the `greeting` message sent from the source chain. Invoked
     * by the relayer.
     *
     * @param payload The raw payload sent from the origin chain
     * @param sourceAddress The raw payload sent from the origin chain
     * @param sourceChain the address of the contract on the target chain the message should be relayed to
     */
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory, // additionalVaas
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 // deliveryHash
    ) public payable override {
        // Don't allow any messages from senders besides the one we're expecting
        require(msg.sender == address(wormholeRelayer), "Only relayer allowed");

        // Just add the greeting string to the array.
        // Note: for simplicity, this does _not_ handle duplicate suppresion so
        //  it is possible to have duplicate messages from the same
        //  originating transaction on the source chain.
        string memory greeting = abi.decode(payload, (string));
        greetings.push(greeting);

        // Emit an event to signal that we've received the message
        emit GreetingReceived(
            greeting,
            sourceChain,
            fromWormholeFormat(sourceAddress)
        );
    }
}

// fromWormholeFormat converts a 32 byte address (for xchain compatability)
// to a 20 byte address that is standard on EVM chains.
function fromWormholeFormat(bytes32 whFormatAddress) pure returns (address) {
    if (uint256(whFormatAddress) >> 160 != 0)
        revert NotAnEvmAddress(whFormatAddress);
    return address(uint160(uint256(whFormatAddress)));
}
