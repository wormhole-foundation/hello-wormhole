// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";
import "wormhole-solidity-sdk/WormholeRelayerSDK.sol";

contract HelloWormholeConfirmation is Base, IWormholeReceiver {
    event GreetingReceived(string greeting, uint16 senderChain, address sender);
    event GreetingSuccess(string greeting, address sender);

    uint256 constant SENDING_GAS_LIMIT = 550_000;
    uint256 constant CONFIRMATION_GAS_LIMIT = 50_000;

    string public latestGreeting;
    string public latestConfirmedSentGreeting;

    uint16 chainId;

    enum MessageType {
        GREETING,
        CONFIRMATION
    }

    constructor(
        address _wormholeRelayer,
        address _wormhole
    ) Base(_wormholeRelayer, _wormhole) {}

    function quoteCrossChainGreeting(
        uint16 targetChain,
        uint256 receiverValue
    ) public view returns (uint256 cost) {
        (cost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            receiverValue,
            SENDING_GAS_LIMIT
        );
    }

    // receiverValueForSecondDeliveryPayment will be determined in a front-end calculation (by calling quoteConfirmation on the target chain)
    // We recommend baking in a buffer to account for the possibility of the price of targetChain->sourceChain changing during the sourceChain->targetChain delivery
    function sendCrossChainGreeting(
        uint16 targetChain,
        address targetAddress,
        string memory greeting,
        uint256 receiverValueForSecondDeliveryPayment
    ) public payable {
        uint256 cost = quoteCrossChainGreeting(
            targetChain,
            receiverValueForSecondDeliveryPayment
        );
        require(msg.value == cost);

        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            targetAddress,
            abi.encode(MessageType.GREETING, greeting, msg.sender), // payload
            receiverValueForSecondDeliveryPayment, // will be used to pay for the confirmation
            SENDING_GAS_LIMIT,
            // we add a refund chain and address as the requester of the cross chain greeting
            chainId,
            msg.sender
        );
    }

    function quoteConfirmation(
        uint16 targetChain
    ) public view returns (uint256 cost) {
        (cost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            0,
            CONFIRMATION_GAS_LIMIT
        );
    }

    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory, // additionalVaas
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 // deliveryHash
    )
        public
        payable
        override
        onlyWormholeRelayer
        isRegisteredSender(sourceChain, sourceAddress)
    {
        MessageType msgType = abi.decode(payload, (MessageType));

        if (msgType == MessageType.GREETING) {
            (, string memory greeting, address sender) = abi.decode(
                payload,
                (MessageType, string, address)
            );
            latestGreeting = greeting;
            emit GreetingReceived(latestGreeting, sourceChain, sender);

            uint256 confirmationCost = quoteConfirmation(sourceChain);
            require(
                msg.value >= confirmationCost,
                "Didn't receive enough value for the second send!"
            );
            wormholeRelayer.sendPayloadToEvm{value: confirmationCost}(
                sourceChain,
                fromWormholeFormat(sourceAddress),
                abi.encode(MessageType.CONFIRMATION, greeting, sender),
                0,
                CONFIRMATION_GAS_LIMIT
            );
        } else if (msgType == MessageType.CONFIRMATION) {
            (, string memory greeting, address sender) = abi.decode(
                payload,
                (MessageType, string, address)
            );
            emit GreetingSuccess(greeting, sender);
            latestConfirmedSentGreeting = greeting;
        }
    }
}
