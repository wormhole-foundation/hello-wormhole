// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";

contract HelloWormhole is IWormholeReceiver {
    event GreetingReceived(string greeting, uint16 senderChain, address sender);

    uint256 constant GAS_LIMIT = 50_000;

    IWormholeRelayer public immutable wormholeRelayer;

    string public latestGreeting;

    constructor(address _wormholeRelayer) {
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
    }

    function sendCrossChainGreeting(uint16 targetChain, address targetAddress, string memory greeting) public payable {
        wormholeRelayer.sendPayloadToEvm(
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
        bytes32 // deliveryHash
    ) public payable override {
        require(msg.sender == address(wormholeRelayer), "Only relayer allowed");

        latestGreeting = abi.decode(payload, (string));

        emit GreetingReceived(latestGreeting, sourceChain, fromWormholeFormat(sourceAddress));
    }
}

function fromWormholeFormat(bytes32 whFormatAddress) pure returns (address) {
    if (uint256(whFormatAddress) >> 160 != 0) {
        revert NotAnEvmAddress(whFormatAddress);
    }
    return address(uint160(uint256(whFormatAddress)));
}
