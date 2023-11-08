# Beyond HelloWormhole - Protections, Refunds, Chained Deliveries, and More

In Part 1 ([HelloWormhole](./README.md)), we wrote a fully functioning cross-chain application that allows users to request, from one contract, that a `GreetingReceived` event to be emitted from one of the other contracts on a different chain.

In Part 2 ([How does Hello Wormhole Work?](./hello-wormhole-explained.md)), we discussed how the Wormhole Relayer contract works behind the scenes. In summary, it works by publishing a wormhole message with delivery instructions, which alerts a delivery provider to call the `deliver` endpoint of the Wormhole Relayer contract on the target chain, finally calling the designated `targetAddress` with the correct inputs

HelloWormhole is a great example application, but has much room for improvement. Let's talk through some ways to improve both the security and features of the application!

Topics covered:

- Restricting the sender
- Refunds
- Chained Deliveries
- Delivering existing VAAs

## Protections

### Issue: The greetings can come from anyone

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

### Example Solution for Problem 1

We provide a base class in the [Wormhole Solidity SDK](https://github.com/wormhole-foundation/wormhole-solidity-sdk) that includes the modifier shown above, makes it easy to add these functionalities as such

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
