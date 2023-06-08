// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../../src/interfaces/IWormholeRelayer.sol";
import "./BytesParsing.sol";

import "forge-std/console.sol";

uint8 constant VERSION_VAAKEY = 1;
uint8 constant VERSION_DELIVERY_OVERRIDE = 1;
uint8 constant PAYLOAD_ID_DELIVERY_INSTRUCTION = 1;
uint8 constant PAYLOAD_ID_REDELIVERY_INSTRUCTION = 2;

using BytesParsing for bytes;

struct DeliveryInstruction {
    uint16 targetChain;
    bytes32 targetAddress;
    bytes payload;
    uint256 requestedReceiverValue;
    uint256 extraReceiverValue;
    bytes encodedExecutionInfo;
    uint16 refundChain;
    bytes32 refundAddress;
    bytes32 refundDeliveryProvider;
    bytes32 sourceDeliveryProvider;
    bytes32 senderAddress;
    VaaKey[] vaaKeys;
}

function decodeDeliveryInstruction(
    bytes memory encoded
) pure returns (DeliveryInstruction memory strct) {
    uint256 offset = checkUint8(encoded, 0, PAYLOAD_ID_DELIVERY_INSTRUCTION);

    uint256 requestedReceiverValue;
    uint256 extraReceiverValue;

    (strct.targetChain, offset) = encoded.asUint16Unchecked(offset);
    (strct.targetAddress, offset) = encoded.asBytes32Unchecked(offset);
    (strct.payload, offset) = decodeBytes(encoded, offset);
    (requestedReceiverValue, offset) = encoded.asUint256Unchecked(offset);
    (extraReceiverValue, offset) = encoded.asUint256Unchecked(offset);
    (strct.encodedExecutionInfo, offset) = decodeBytes(encoded, offset);
    (strct.refundChain, offset) = encoded.asUint16Unchecked(offset);
    (strct.refundAddress, offset) = encoded.asBytes32Unchecked(offset);
    (strct.refundDeliveryProvider, offset) = encoded.asBytes32Unchecked(offset);
    (strct.sourceDeliveryProvider, offset) = encoded.asBytes32Unchecked(offset);
    (strct.senderAddress, offset) = encoded.asBytes32Unchecked(offset);
    (strct.vaaKeys, offset) = decodeVaaKeyArray(encoded, offset);

    strct.requestedReceiverValue = requestedReceiverValue;
    strct.extraReceiverValue = extraReceiverValue;

    checkLength(encoded, offset);
}

function encodeVaaKeyArray(
    VaaKey[] memory vaaKeys
) pure returns (bytes memory encoded) {
    assert(vaaKeys.length < type(uint8).max);
    encoded = abi.encodePacked(uint8(vaaKeys.length));
    for (uint256 i = 0; i < vaaKeys.length; ) {
        encoded = abi.encodePacked(encoded, encodeVaaKey(vaaKeys[i]));
        unchecked {
            ++i;
        }
    }
}

function decodeVaaKeyArray(
    bytes memory encoded,
    uint256 startOffset
) pure returns (VaaKey[] memory vaaKeys, uint256 offset) {
    uint8 vaaKeysLength;
    (vaaKeysLength, offset) = encoded.asUint8Unchecked(startOffset);
    vaaKeys = new VaaKey[](vaaKeysLength);
    for (uint256 i = 0; i < vaaKeys.length; ) {
        (vaaKeys[i], offset) = decodeVaaKey(encoded, offset);
        unchecked {
            ++i;
        }
    }
}

function encodeVaaKey(
    VaaKey memory vaaKey
) pure returns (bytes memory encoded) {
    encoded = abi.encodePacked(
        encoded,
        VERSION_VAAKEY,
        vaaKey.chainId,
        vaaKey.emitterAddress,
        vaaKey.sequence
    );
}

function decodeVaaKey(
    bytes memory encoded,
    uint256 startOffset
) pure returns (VaaKey memory vaaKey, uint256 offset) {
    offset = checkUint8(encoded, startOffset, VERSION_VAAKEY);
    (vaaKey.chainId, offset) = encoded.asUint16Unchecked(offset);
    (vaaKey.emitterAddress, offset) = encoded.asBytes32Unchecked(offset);
    (vaaKey.sequence, offset) = encoded.asUint64Unchecked(offset);
}

function encodeBytes(bytes memory payload) pure returns (bytes memory encoded) {
    //casting payload.length to uint32 is safe because you'll be hard-pressed to allocate 4 GB of
    //  EVM memory in a single transaction
    encoded = abi.encodePacked(uint32(payload.length), payload);
}

function decodeBytes(
    bytes memory encoded,
    uint256 startOffset
) pure returns (bytes memory payload, uint256 offset) {
    uint32 payloadLength;
    (payloadLength, offset) = encoded.asUint32Unchecked(startOffset);
    (payload, offset) = encoded.sliceUnchecked(offset, payloadLength);
}

function checkUint8(
    bytes memory encoded,
    uint256 startOffset,
    uint8 expectedPayloadId
) pure returns (uint256 offset) {
    uint8 parsedPayloadId;
    (parsedPayloadId, offset) = encoded.asUint8Unchecked(startOffset);
    if (parsedPayloadId != expectedPayloadId) {
        revert InvalidPayloadId(parsedPayloadId, expectedPayloadId);
    }
}

function checkLength(bytes memory encoded, uint256 expected) pure {
    if (encoded.length != expected) {
        revert InvalidPayloadLength(encoded.length, expected);
    }
}
