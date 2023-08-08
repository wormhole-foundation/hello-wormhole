# Beyond HelloWormhole - Protections, Refunds, Chained Deliveries, and More

In Part 1 ([HelloWormhole](./README.md)), we wrote a fully functioning cross-chain application that allows users to request, from one contract, that a `GreetingReceived` event to be emitted from one of the other contracts on a different chain.

In Part 2 ([How does Hello Wormhole Work?](./hello-wormhole-explained.md)), we discussed how the Wormhole Relayer contract works behind the scenes. In summary, it works by publishing a wormhole message with delivery instructions, which alerts a delivery provider to call the `deliver` endpoint of the Wormhole Relayer contract on the target chain, finally calling the designated `targetAddress` with the correct inputs

HelloWormhole is a great example application, but has much room for improvement. Let's talk through some ways to improve both the security and features of the application!

Topics covered:

- Protections
  - Restricting the sender
  - Preventing duplicate deliveries
- Refunds
- Forwarding
- Delivering existing VAAs

## Protections

### Problem 1 - The greetings can come from anyone

A user doesn’t have to go through the HelloWormhole contract to request a greeting - they can call `wormholeRelayer.sendPayloadToEvm{value: cost}(…)` themselves!

This is not ideal if, for example, you wanted to store some information in the source HelloWormhole contract every time a `sendCrossChainGreeting` was requested.

Often, it is desirable that all of the requests go through your own source contract.

**Solution:** We can check, in our implementation of `receiveWormholeMessages`, that `sourceChain` and `sourceAddress` are a valid HelloWormhole contract, and revert otherwise

```solidity
    address registrationOwner;
    mapping(uint16 => bytes32) registeredSenders;

    modifier isRegisteredSender(uint16 sourceChain, bytes32 sourceAddress) {
        require(registeredSenders[sourceChain] == sourceAddress, "Not registered sender");
        _;
    }

    /**
     * Sets the registered address for 'sourceChain' to 'sourceAddress'
     * So that for messages from 'sourceChain', only ones from 'sourceAddress' are valid
     *
     * Assumes only one sender per chain is valid
     * Sender is the address that called 'send' on the Wormhole Relayer contract on the source chain)
     */
    function setRegisteredSender(uint16 sourceChain, bytes32 sourceAddress) public {
        require(msg.sender == registrationOwner, "Not allowed to set registered sender");
        registeredSenders[sourceChain] = sourceAddress;
    }
```

### Problem 2 - The greetings can be relayed multiple times

As mentioned in the first article, without having the mapping of delivery hashes to boolean, anyone can fetch the delivery VAA corresponding to a sent greeting, and have it delivered again to the target HelloWormhole contract! This causes another `GreetingReceived` event to be emitted from the same `senderChain` and `sender`, even though the sender only intended on sending this greeting once.

**Solution:** In our implementation of receiveWormholeMessages, we store each delivery hash in a mapping from delivery hashes to booleans, to indicate that the delivery has already been processed. Then, at the beginning we can check to see if the delivery has already been processed, and revert if it has.

```solidity

    mapping(bytes32 => bool) public seenDeliveryVaaHashes;

    modifier replayProtect(bytes32 deliveryHash) {
        require(!seenDeliveryVaaHashes[deliveryHash], "Message already processed");
        seenDeliveryVaaHashes[deliveryHash] = true;
        _;
    }
```

### Example Solution for Problems 1 and 2

We provide a base class in the [Wormhole Solidity SDK](https://github.com/wormhole-foundation/wormhole-solidity-sdk) that includes the modifiers shown above, makes it easy to add these functionalities as such

```solidity
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
```

Included in the HelloWormhole repository is an [example contract](https://github.com/wormhole-foundation/hello-wormhole/blob/main/src/extensions/HelloWormholeProtections.sol) (and [forge tests](https://github.com/wormhole-foundation/hello-wormhole/blob/main/test/extensions/HelloWormholeProtections.t.sol)) that uses these helpers:

You can add these helpers into your own project as such:

```bash
forge install wormhole-foundation/wormhole-solidity-sdk
```

## Feature: Receive Refunds

Often, you cannot predict exactly how much gas your contract will use. To avoid the chance of a 'Receiver Failure' (which occurs when your contract reverts - because, for example, it runs out of gas), you should request a reasonable upper bound for how much gas your contract will use.

However, this means if, e.g. we expect HelloWormhole to take somewhere (uniformly random) between 10000 and 50000 units of gas, we are losing on expectation the cost of 20000 units of gas if we request 50000 units of gas for every request!

Fortunately, the `IWormholeRelayer` interface [allows you to receive refunds](https://github.com/wormhole-foundation/wormhole/blob/main/ethereum/contracts/interfaces/relayer/IWormholeRelayer.sol#L89) for any gas you do not end up using in your target contract!

```solidity

function sendPayloadToEvm(
    uint16 targetChain,
    address targetAddress,
    bytes memory payload,
    uint256 receiverValue,
    uint256 gasLimit,
    **uint16 refundChain,
    address refundAddress**
) external payable returns (uint64 sequence);
```

If these are specified, then different logic is applied depending on the values of `refundChain` and `targetChain`

**If refundChain is equal to targetChain**, a refund of

```solidity
targetChainRefundPerGasUnused * (gasLimit - gasUsed)
```

will be sent to address `refundAddress` on the target chain.

- **gasUsed** is the amount of gas your contract (at `targetAddress`) uses in the call to `receiveWormholeMessages`.

> Note that this must be less than or equal to gasLimit.

- **targetChainRefundPerGasUnused** is a constant quoted pre-delivery by the delivery provider - this is the second return value of the `quoteEVMDeliveryPrice` function:

```solidity
function quoteEVMDeliveryPrice(
        uint16 targetChain,
        uint256 receiverValue,
        uint256 gasLimit
) external view returns (uint256 nativePriceQuote, uint256 targetChainRefundPerGasUnused);
```

**else** (if refundChain is not equal to targetChain), then

1. The cost to perform a delivery with a gas limit and receiver value of 0 to the refund chain will be calculated (let’s call it BASE_COST)

2. **if** `TARGET_CHAIN_REFUND = targetChainRefundPerGasUnused * (gasLimit - gasUsed)` **is larger than BASE_COST**, then a delivery will be performed, and the `msg.value` that will be sent to `refundAddress` on `refundChain` will be

```solidity
targetChainWormholeRelayer.quoteNativeForChain(refundChain, TARGET_CHAIN_REFUND - BASE_COST, deliveryProviderAddress)
```

> Note: deliveryProviderAddress here is equal to `targetChainWormholeRelayer.quoteDefaultDeliveryProvider`

Included in the HelloWormhole repository is an [example contract](https://github.com/wormhole-foundation/hello-wormhole/blob/main/src/extensions/HelloWormholeRefunds.sol) (and [forge tests](https://github.com/wormhole-foundation/hello-wormhole/blob/main/test/extensions/HelloWormholeRefunds.t.sol)) that use this refund feature.

## Feature: Going from chain A → chain B → chain C

Suppose you wish to request a delivery from chain A to chain B, and then after the delivery has completed on chain B, you wish to deliver some information to chain C.

One way to do this is to call `sendPayloadToEvm` within the implementation of `receiveWormholeMessages` on chain B. Often in these scenarios, you only have currency on chain A, but you can still request the appropriate amount as your `receiverValue` in your delivery request on chain A.

How do you know how much receiver value to request in your delivery on chain A? Unfortunately, the amount you need depends on a quote that the delivery provider on chain B can provide. Our best recommendation here is to expose this 'receiverValue' amount as a parameter on your contract's endpoint, and have the front-end of your application determine the correct value to pass here by querying the WormholeRelayer contract on chain B.

Included in the HelloWormhole repository is an [example contract](https://github.com/wormhole-foundation/hello-wormhole/blob/main/src/extensions/HelloWormholeConfirmation.sol) (and [forge tests](https://github.com/wormhole-foundation/hello-wormhole/blob/main/test/extensions/HelloWormholeConfirmation.t.sol)) that go from chain A to chain B to chain C, using the recommendation above.

There is still a downside - if you had provided a `refundAddress`, you are likely entitled to some amount of chain B currency as a refund from your chain A → B delivery! Ideally, you’d like to use this refund as part of the funding towards executing your B → C delivery request. If that isn’t possible, your next best options are to provide a wallet on the target chain to receive your refund, or request your refund be sent to a different chain (in which case you lose a portion of your refund to the fee of an additional delivery).

We provide an [alternative way to achieve this that provides some cost savings: Forwarding](https://github.com/wormhole-foundation/wormhole/blob/main/ethereum/contracts/interfaces/relayer/IWormholeRelayer.sol#L271). The purpose of forwarding is to use the refund from chain A → B to add to the funding of the delivery from chain B → C.

Included in the HelloWormhole repository is an [example contract](https://github.com/wormhole-foundation/hello-wormhole/blob/main/src/extensions/HelloWormholeForwarding.sol) (and [forge tests](https://github.com/wormhole-foundation/hello-wormhole/blob/main/test/extensions/HelloWormholeForwarding.t.sol)) that use the forwarding feature as described, along with the 'front-end' recommendation described above.

Simply use `forwardPayloadToEvm` instead of `sendPayloadToEvm` to use this functionality!

```solidity
/*
 * The following equation must be satisfied
 * (sum_f indicates summing over all forwards requested in
 * `receiveWormholeMessages`):
 * (refund amount from current execution of receiveWormholeMessages)
 * + sum_f [msg.value_f]
 * >= sum_f [quoteEVMDeliveryPrice(targetChain_f, receiverValue_f, gasLimit_f)]
 */

function forwardPayloadToEvm(
        uint16 targetChain,
        address targetAddress,
        bytes memory payload,
        uint256 receiverValue,
        uint256 gasLimit
) external payable;
```

> Note: If at least one forward is requested and there doesn’t end up being enough of a refund leftover to complete the forward(s), then the full delivery on chain B will revert, and the status (emitted in an event from the Wormhole Relayer contract) will be ‘FORWARD_REQUEST_FAILURE’.

If all the forwards requested are able to be executed (i.e. there is enough of a refund leftover such that all of them can be funded), the status will be `FORWARD_REQUEST_SUCCESS`

## Composing with other Wormhole modules - Requesting Delivery of Existing Wormhole Messages

Often times, we wish to deliver a wormhole message that has already been published (by a different contract).

To do this, use the [sendVaasToEvm](https://github.com/wormhole-foundation/wormhole/blob/main/ethereum/contracts/interfaces/relayer/IWormholeRelayer.sol#L149) function, which lets you specify additional published wormhole messages for which the corresponding signed VAAs will be pass in as a parameter in the call to `targetAddress`

```solidity
/**
 * @notice VaaKey identifies a wormhole message
 *
 * @custom:member chainId Wormhole chain ID of the chain where this VAA was emitted from
 * @custom:member emitterAddress Address of the emitter of the VAA, in Wormhole bytes32 format
 * @custom:member sequence Sequence number of the VAA
 */
struct VaaKey {
    uint16 chainId;
    bytes32 emitterAddress;
    uint64 sequence;
}

function sendVaasToEvm(
        uint16 targetChain,
        address targetAddress,
        bytes memory payload,
        uint256 receiverValue,
        uint256 gasLimit,
        VaaKey[] memory vaaKeys,
        uint16 refundChain,
        address refundAddress
) external payable returns (uint64 sequence);
```

For an example usage of this, see the Wormhole Solidity SDK’s implementation of [sendTokenWithPayloadToEvm](https://github.com/wormhole-foundation/wormhole-solidity-sdk/blob/main/src/WormholeRelayerSDK.sol#L131), which use the TokenBridge wormhole module to send tokens!
