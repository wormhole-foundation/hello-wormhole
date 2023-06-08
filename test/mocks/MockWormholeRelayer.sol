// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../src/interfaces/IWormholeRelayer.sol";
import "../../src/interfaces/IWormholeReceiver.sol";

// contract MockWormholeRelayer is IWormholeRelayer {
contract MockWormholeRelayer {
    uint16 public constant chainId = 4;

    uint64 public sequence_ = 0;

    constructor() {}

    PackedDelivery[] public pendingDeliveries;

    struct PackedDelivery {
        // send args
        uint16 targetChain;
        address targetAddress;
        uint256 receiverValue;
        uint256 gasLimit;
        // delivery args
        bytes payload;
        bytes[] additionalVaas;
        bytes32 sourceAddress;
        uint16 sourceChain;
        bytes32 deliveryHash;
    }

    function performRecordedDeliveryFiFo() public {
        PackedDelivery memory delivery = pendingDeliveries[0];
        IWormholeReceiver(delivery.targetAddress).receiveWormholeMessages(
            delivery.payload,
            delivery.additionalVaas,
            delivery.sourceAddress,
            delivery.sourceChain,
            delivery.deliveryHash
        );
        delete pendingDeliveries[0];
        for (uint256 i = 1; i < pendingDeliveries.length; i++) {
            pendingDeliveries[i - 1] = pendingDeliveries[i];
        }
        pendingDeliveries.pop();
    }

    function performRecordedDeliveries() public {
        for (uint256 i = 0; i < pendingDeliveries.length; i++) {
            PackedDelivery memory delivery = pendingDeliveries[i];
            IWormholeReceiver(delivery.targetAddress).receiveWormholeMessages{
                value: delivery.receiverValue,
                gas: delivery.gasLimit
            }(
                delivery.payload,
                delivery.additionalVaas,
                delivery.sourceAddress,
                delivery.sourceChain,
                delivery.deliveryHash
            );
        }
        delete pendingDeliveries;
    }

    function sendPayloadToEvm(
        uint16 targetChain,
        address targetAddress,
        bytes memory payload,
        uint256 receiverValue,
        uint256 gasLimit
    ) public payable returns (uint64 sequence) {
        pendingDeliveries.push(
            PackedDelivery({
                targetChain: targetChain,
                targetAddress: targetAddress,
                receiverValue: receiverValue,
                gasLimit: gasLimit,
                payload: payload,
                additionalVaas: new bytes[](0),
                sourceAddress: toWormholeFormat(msg.sender),
                sourceChain: chainId,
                deliveryHash: bytes32(0)
            })
        );
        // not the real calculation, but good enough for testing
        pendingDeliveries[pendingDeliveries.length - 1]
            .deliveryHash = keccak256(
            abi.encode(pendingDeliveries[pendingDeliveries.length - 1])
        );
        return sequence_++;
    }

    // function sendVaasToEvm(
    //     uint16 targetChain,
    //     address targetAddress,
    //     bytes memory payload,
    //     uint256 receiverValue,
    //     uint256 gasLimit,
    //     VaaKey[] memory vaaKeys
    // ) external payable returns (uint64 sequence) {
    //     pendingDeliveries.push(
    //         PackedDelivery({
    //             targetChain: targetChain,
    //             targetAddress: targetAddress,
    //             receiverValue: receiverValue,
    //             gasLimit: gasLimit,
    //             payload: payload,
    //             additionalVaas: vaaKeys,
    //             sourceAddress: toWormholeFormat(msg.sender),
    //             sourceChain: chainId,
    //             deliveryHash: bytes32(0)
    //         })
    //     );
    //     // not the real calculation, but good enough for testing
    //     pendingDeliveries[pendingDeliveries.length - 1]
    //         .deliveryHash = keccak256(
    //         abi.encode(pendingDeliveries[pendingDeliveries.length - 1])
    //     );
    //     return sequence_++;
    // }

    function quoteEVMDeliveryPrice(
        uint16, // targetChain,
        uint256 receiverValue,
        uint256 gasLimit
    )
        public
        pure
        returns (
            uint256 nativePriceQuote,
            uint256 targetChainRefundPerGasUnused
        )
    {
        return (1e16 + receiverValue + gasLimit * 5e10, 5e10);
    }

    function forwardPayloadToEvm(
        uint16 targetChain,
        address targetAddress,
        bytes memory payload,
        uint256 receiverValue,
        uint256 gasLimit
    ) public payable {
        sendPayloadToEvm(
            targetChain,
            targetAddress,
            payload,
            receiverValue,
            gasLimit
        );
    }

    function fromWormholeFormat(
        bytes32 whFormatAddress
    ) public pure returns (address) {
        if (uint256(whFormatAddress) >> 160 != 0)
            revert NotAnEvmAddress(whFormatAddress);
        return address(uint160(uint256(whFormatAddress)));
    }

    function toWormholeFormat(address addr) public pure returns (bytes32) {
        return bytes32(uint256(uint160(addr)));
    }

    receive() external payable {}

    // function getRegisteredWormholeRelayerContract(
    //     uint16 chainId
    // ) external view returns (bytes32) {
    //     revert("Not Implemented");
    // }

    // function sendPayloadToEvm(
    //     uint16 targetChain,
    //     address targetAddress,
    //     bytes memory payload,
    //     uint256 receiverValue,
    //     uint256 gasLimit,
    //     uint16 refundChain,
    //     address refundAddress
    // ) external payable override returns (uint64 sequence) {
    //     revert("Not Implemented");
    // }

    // function sendVaasToEvm(
    //     uint16 targetChain,
    //     address targetAddress,
    //     bytes memory payload,
    //     uint256 receiverValue,
    //     uint256 gasLimit,
    //     VaaKey[] memory vaaKeys,
    //     uint16 refundChain,
    //     address refundAddress
    // ) external payable returns (uint64 sequence) {
    //     revert("Not Implemented");
    // }

    // function sendToEvm(
    //     uint16 targetChain,
    //     address targetAddress,
    //     bytes memory payload,
    //     uint256 receiverValue,
    //     uint256 paymentForExtraReceiverValue,
    //     uint256 gasLimit,
    //     uint16 refundChain,
    //     address refundAddress,
    //     address deliveryProviderAddress,
    //     VaaKey[] memory vaaKeys,
    //     uint8 consistencyLevel
    // ) external payable returns (uint64 sequence) {
    //     revert("Not Implemented");
    // }

    // function send(
    //     uint16 targetChain,
    //     bytes32 targetAddress,
    //     bytes memory payload,
    //     uint256 receiverValue,
    //     uint256 paymentForExtraReceiverValue,
    //     bytes memory encodedExecutionParameters,
    //     uint16 refundChain,
    //     bytes32 refundAddress,
    //     address deliveryProviderAddress,
    //     VaaKey[] memory vaaKeys,
    //     uint8 consistencyLevel
    // ) external payable returns (uint64 sequence) {
    //     revert("Not Implemented");
    // }

    // function forwardVaasToEvm(
    //     uint16 targetChain,
    //     address targetAddress,
    //     bytes memory payload,
    //     uint256 receiverValue,
    //     uint256 gasLimit,
    //     VaaKey[] memory vaaKeys
    // ) external payable {
    //     revert("Not Implemented");
    // }

    // function forwardToEvm(
    //     uint16 targetChain,
    //     address targetAddress,
    //     bytes memory payload,
    //     uint256 receiverValue,
    //     uint256 paymentForExtraReceiverValue,
    //     uint256 gasLimit,
    //     uint16 refundChain,
    //     address refundAddress,
    //     address deliveryProviderAddress,
    //     VaaKey[] memory vaaKeys,
    //     uint8 consistencyLevel
    // ) external payable {
    //     revert("Not Implemented");
    // }

    // function forward(
    //     uint16 targetChain,
    //     bytes32 targetAddress,
    //     bytes memory payload,
    //     uint256 receiverValue,
    //     uint256 paymentForExtraReceiverValue,
    //     bytes memory encodedExecutionParameters,
    //     uint16 refundChain,
    //     bytes32 refundAddress,
    //     address deliveryProviderAddress,
    //     VaaKey[] memory vaaKeys,
    //     uint8 consistencyLevel
    // ) external payable {
    //     revert("Not Implemented");
    // }

    // function resendToEvm(
    //     VaaKey memory deliveryVaaKey,
    //     uint16 targetChain,
    //     uint256 newReceiverValue,
    //     uint256 newGasLimit,
    //     address newDeliveryProviderAddress
    // ) external payable returns (uint64 sequence) {
    //     revert("Not Implemented");
    // }

    // function resend(
    //     VaaKey memory deliveryVaaKey,
    //     uint16 targetChain,
    //     uint256 newReceiverValue,
    //     bytes memory newEncodedExecutionParameters,
    //     address newDeliveryProviderAddress
    // ) external payable returns (uint64 sequence) {
    //     revert("Not Implemented");
    // }

    // function quoteEVMDeliveryPrice(
    //     uint16 targetChain,
    //     uint256 receiverValue,
    //     uint256 gasLimit,
    //     address deliveryProviderAddress
    // )
    //     external
    //     view
    //     returns (
    //         uint256 nativePriceQuote,
    //         uint256 targetChainRefundPerGasUnused
    //     )
    // {
    //     revert("Not Implemented");
    // }

    // function quoteDeliveryPrice(
    //     uint16 targetChain,
    //     uint256 receiverValue,
    //     bytes memory encodedExecutionParameters,
    //     address deliveryProviderAddress
    // )
    //     external
    //     view
    //     returns (uint256 nativePriceQuote, bytes memory encodedExecutionInfo)
    // {
    //     revert("Not Implemented");
    // }

    // function quoteNativeForChain(
    //     uint16 targetChain,
    //     uint256 currentChainAmount,
    //     address deliveryProviderAddress
    // ) external view returns (uint256 targetChainAmount) {
    //     revert("Not Implemented");
    // }

    // /**
    //  * @notice Returns the address of the current default delivery provider
    //  * @return deliveryProvider The address of (the default delivery provider)'s contract on this source
    //  *   chain. This must be a contract that implements IDeliveryProvider.
    //  */
    // function getDefaultDeliveryProvider()
    //     external
    //     view
    //     returns (address deliveryProvider)
    // {
    //     revert("Not Implemented");
    // }

    // function deliver(
    //     bytes[] memory encodedVMs,
    //     bytes memory encodedDeliveryVAA,
    //     address payable relayerRefundAddress,
    //     bytes memory deliveryOverrides
    // ) external payable {
    //     revert("Not Implemented");
    // }
}
