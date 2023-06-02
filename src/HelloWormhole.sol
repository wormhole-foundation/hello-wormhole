// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IWormholeRelayer.sol";
import "./interfaces/IWormholeReceiver.sol";

contract HelloWormhole is IWormholeReceiver {
    IWormholeRelayer public immutable wormholeRelayer;

    event MessageReceived(string greeting, uint16 senderChain, address sender);

    constructor(address _wormholeRelayer) {
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
    }

    function sendGreeting(
        uint16 targetChain,
        address targetAddress,
        string memory greeting
    ) public payable {
        bytes memory payload = abi.encode(greeting);
        uint256 gasRequired = 30_000;
        (uint256 cost, ) = wormholeRelayer.quoteEVMDeliveryPrice(
            targetChain,
            0,
            gasRequired
        );
        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            targetAddress,
            payload,
            0, // no receiver value needed
            gasRequired
        );
        if (msg.value > cost) {
            (bool success, ) = msg.sender.call{value: msg.value - cost}("");
            require(success, "Returning excess funds failed");
        }
    }

    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory, // additionalVaas
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 // deliveryHash
    ) public payable override {
        address sender = fromWormholeFormat(sourceAddress);
        string memory greeting = abi.decode(payload, (string));

        emit MessageReceived(greeting, sourceChain, sender);
    }
}

function fromWormholeFormat(bytes32 whFormatAddress) pure returns (address) {
    if (uint256(whFormatAddress) >> 160 != 0)
        revert NotAnEvmAddress(whFormatAddress);
    return address(uint160(uint256(whFormatAddress)));
}
