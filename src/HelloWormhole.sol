// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "wormhole-solidity-sdk/interfaces/IWormholeRelayer.sol";
import "wormhole-solidity-sdk/interfaces/IWormholeReceiver.sol";

contract HelloWormhole is IWormholeReceiver {
    event GreetingReceived(string greeting, uint16 senderChain, address sender);
    event EtherReceived(address indexed sender, uint256 amount);
    event ReceivedNonZeroEther(address indexed sender, uint256 amount);

    uint256 constant GAS_LIMIT = 50_000;

    IWormholeRelayer public immutable wormholeRelayer;

    string public latestGreeting;

    modifier onlyWormholeRelayer() {
        require(msg.sender == address(wormholeRelayer), "Only relayer allowed");
        _;
    }

    constructor(address _wormholeRelayer) {
        wormholeRelayer = IWormholeRelayer(_wormholeRelayer);
    }

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
        require(msg.value == cost, "Incorrect amount sent");
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
        bytes32, // address that called 'sendPayloadToEvm' (HelloWormhole contract address)
        uint16 sourceChain,
        bytes32 // unique identifier of delivery
    ) public payable override onlyWormholeRelayer {
        // Parse the payload and do the corresponding actions!
        (string memory greeting, address sender) = abi.decode(
            payload,
            (string, address)
        );
        latestGreeting = greeting;
        emit GreetingReceived(latestGreeting, sourceChain, sender);
    }

    // Fallback function to handle unexpected Ether transfers
    receive() external payable {
        // Handle unexpected Ether transfers (if necessary)
        emit EtherReceived(msg.sender, msg.value);

        // Perform additional logic based on the received amount
        if (msg.value > 0) {
            // Perform some action or trigger an event based on the received amount
            emit ReceivedNonZeroEther(msg.sender, msg.value);
        } else {
            // Reject the transfer if the received amount is zero
            revert("Received zero Ether");
        }
    }
}
