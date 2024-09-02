# Building Your First Cross-Chain Application

This tutorial contains a solidity contract (`HelloWormhole.sol`) that can be deployed onto many EVM chains to form a fully functioning cross-chain application.

Specifically, we will write and deploy a contract onto many chains that allows users to request, from one contract, that a `GreetingReceived` event be emitted from a contracts on a _different chain_.

This also allows users to pay for their custom greeting to be emitted on a chain that they do not have any gas funds for!

### Understanding the Workflow

In cross-chain applications, messages are passed between chains using 
Wormhole's infrastructure. The functions you will implement here, 
such as `sendCrossChainGreeting`, play a crucial role in this process 
by ensuring that messages are properly formatted, sent, and received 
across different blockchain environments.

### Visual Guide

The following diagram illustrates the typical workflow:

1. **Message Emission**: A message is emitted on the source chain (e.g., Ethereum).
2. **VAA Creation**: The message is observed by the Guardian Network, 
   which creates a Verifiable Action Approval (VAA).
3. **Relaying the VAA**: The VAA is then relayed by a relayer 
   (either standard or specialized) to the target chain (e.g., Avalanche).
4. **Message Processing**: The target chain processes the VAA and 
   performs the intended action, such as emitting an event.

Understanding this process will help you follow the code implementation more effectively.

## Getting Started

Included in the [repository](https://github.com/wormhole-foundation/hello-wormhole) is:

- Example Solidity Code
- Example Forge local testing setup
- Testnet Deploy Scripts
- Example Testnet testing setup

### Environment Setup

- Node 16.14.1 or later, npm 8.5.0 or later: [https://docs.npmjs.com/downloading-and-installing-node-js-and-npm](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm)
- forge 0.2.0 or later: [https://book.getfoundry.sh/getting-started/installation](https://book.getfoundry.sh/getting-started/installation)

### Testing Locally

Pull the code down from github and cd into the directory, then build and test it.

```bash
git clone https://github.com/wormhole-foundation/hello-wormhole.git
cd hello-wormhole
npm run build
forge test
```

Expected output is

```bash
Running 1 test for test/HelloWormhole.t.sol:HelloWormholeTest
[PASS] testGreeting() (gas: 777229)
Test result: ok. 1 passed; 0 failed; finished in 3.98s
```

### Deploying to Testnet

You will need a wallet with at least 0.05 Testnet AVAX and 0.01 Testnet CELO.

- [Obtain testnet AVAX here](https://core.app/tools/testnet-faucet/?token=C)
- [Obtain testnet CELO here](https://faucet.celo.org/alfajores)

```bash
EVM_PRIVATE_KEY=your_wallet_private_key npm run deploy
```

### Testing on Testnet

You will need a wallet with at least 0.02 Testnet AVAX. [Obtain testnet AVAX here](https://core.app/tools/testnet-faucet/?token=C)

You must have also deployed contracts onto testnet (as described in the above section).

To test sending and receiving a message on testnet, execute the test as such:

```bash
EVM_PRIVATE_KEY=your_wallet_private_key npm run test
```

## Explanation of the HelloWormhole Cross-chain Contract

Let’s take a simple HelloWorld solidity application, and take it cross-chain!

### Single-chain HelloWorld solidity contract

This single-chain HelloWorld smart contract allows users to send greetings. In other words, it allows them to cause an event `GreetingReceived` to be emitted with their greeting!

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract HelloWorld {
    event GreetingReceived(string greeting, address sender);

    string[] public greetings;

    /**
     * @notice Returns the cost (in wei) of a greeting
     */
    function quoteGreeting() public view returns (uint256 cost) {
        return 0;
    }

    /**
     * @notice Updates the list of 'greetings'
     * and emits a 'GreetingReceived' event with 'greeting'
     */
    function sendGreeting(
        string memory greeting
    ) public payable {
        uint256 cost = quoteGreeting();
        require(msg.value == cost);
        emit GreetingReceived(greeting, msg.sender);
        greetings.push(greeting);
    }
}
```

### Taking HelloWorld cross-chain using Wormhole Automatic Relayers

Suppose we want users to be able to request, through their Ethereum wallet, that a greeting be sent to Avalanche, and vice versa.

Let us begin writing a contract that we can deploy onto Ethereum, Avalanche, or any number of other chains, to enable greetings be sent freely between each contract, irrespective of chain.

We'll want to implement the following function:

```solidity
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
    ) public payable;
```

The Wormhole Relayer contract lets us do exactly this! Let’s take a look at the Wormhole Relayer contract interface.

```solidity
    /**
     * @notice Publishes an instruction for the default delivery provider
     * to relay a payload to the address `targetAddress` on chain `targetChain`
     * with gas limit `gasLimit` and `msg.value` equal to `receiverValue`
     *
     * `targetAddress` must implement the IWormholeReceiver interface
     *
     * This function must be called with `msg.value` equal to `quoteEVMDeliveryPrice(targetChain, receiverValue, gasLimit)`
     *
     * Any refunds (from leftover gas) will be paid to the delivery provider. In order to receive the refunds, use the `sendPayloadToEvm` function
     * with `refundChain` and `refundAddress` as parameters
     *
     * @param targetChain in Wormhole Chain ID format
     * @param targetAddress address to call on targetChain (that implements IWormholeReceiver)
     * @param payload arbitrary bytes to pass in as parameter in call to `targetAddress`
     * @param receiverValue msg.value that delivery provider should pass in for call to `targetAddress` (in targetChain currency units)
     * @param gasLimit gas limit with which to call `targetAddress`.
     * @return sequence sequence number of published VAA containing delivery instructions
     */
    function sendPayloadToEvm(
        uint16 targetChain,
        address targetAddress,
        bytes memory payload,
        uint256 receiverValue,
        uint256 gasLimit
    ) external payable returns (uint64 sequence);
```

The Wormhole Relayer network is powered by **Delivery Providers**, who perform the service of watching for Wormhole Relayer delivery requests and performing the delivery to the intended target chain as instructed.

In exchange for calling your contract at `targetAddress` on `targetChain` and paying the gas fees that your contract consumes, they charge a source chain fee. The fee charged will depend on the conditions of the target network and the fee can be requested from the delivery provider:

```
(deliveryPrice,) = quoteEVMDeliveryPrice(targetChain, receiverValue, gasLimit)
```

### Handling Edge Cases

While the basic functions work for standard scenarios, it's important 
to account for edge cases that might occur during cross-chain messaging. 
Below are additional examples to consider:

#### Message Delivery Failures

In some cases, the message may fail to be delivered to the target chain 
due to network issues or other unforeseen circumstances. Implement error handling 
in your `sendCrossChainGreeting` function to catch and retry or log these failures:

```solidity
function sendCrossChainGreeting(
        uint16 targetChain,
        address targetHelloWormhole,
        string memory greeting
) public payable {
    bytes memory payload = abi.encode(greeting, msg.sender);
    uint256 cost = quoteCrossChainGreeting(targetChain);
    require(msg.value == cost, "Incorrect payment");

    try wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            targetHelloWormhole,
            payload,
            0, // receiver value
            GAS_LIMIT
    ) {
        // Successful delivery logic here
    } catch {
        // Handle failure (e.g., log the issue, retry, or revert)
    }
}

**Handling Different Payload Sizes**
Cross-chain messages may vary in size, and larger payloads can lead to higher costs or failures if they exceed certain limits. Here's how to handle varying payload sizes:
function sendCustomCrossChainGreeting(
        uint16 targetChain,
        address targetHelloWormhole,
        string memory greeting
) public payable {
    bytes memory payload = abi.encode(greeting, msg.sender);
    uint256 payloadSize = payload.length;

    // Adjust gas limit or fees based on payload size
    uint256 adjustedGasLimit = GAS_LIMIT + (payloadSize / 100);  // Example adjustment
    uint256 cost = wormholeRelayer.quoteEVMDeliveryPrice(targetChain, 0, adjustedGasLimit);
    
    require(msg.value >= cost, "Insufficient payment for message size");

    wormholeRelayer.sendPayloadToEvm{value: cost}(
        targetChain,
        targetHelloWormhole,
        payload,
        0, 
        adjustedGasLimit
    );
}

**Real-World Use Cases**
Consider a scenario where you need to send multiple types of data in a single cross-chain message, such as a greeting along with some metadata. Implement the following logic to manage such cases:
function sendComplexCrossChainGreeting(
        uint16 targetChain,
        address targetHelloWormhole,
        string memory greeting,
        bytes memory metadata
) public payable {
    bytes memory payload = abi.encode(greeting, msg.sender, metadata);
    uint256 payloadSize = payload.length;
    uint256 cost = wormholeRelayer.quoteEVMDeliveryPrice(targetChain, 0, GAS_LIMIT + (payloadSize / 100));

    require(msg.value == cost, "Incorrect payment");

    wormholeRelayer.sendPayloadToEvm{value: cost}(
        targetChain,
        targetHelloWormhole,
        payload,
        0,
        GAS_LIMIT + (payloadSize / 100)
    );
}


So, following this interface, we can implement `sendCrossChainGreeting` by simply calling sendPayloadToEvm with the payload being some information we'd like to send, such as the greeting and the sender of the greeting.

```solidity
    uint256 constant GAS_LIMIT = 50_000;

    IWormholeRelayer public immutable wormholeRelayer;

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
        bytes memory payload = abi.encode(greeting, msg.sender);
        uint256 cost = quoteCrossChainGreeting(targetChain);
	    require(msg.value == cost, "Incorrect payment");
        wormholeRelayer.sendPayloadToEvm{value: cost}(
            targetChain,
            targetAddress,
            payload,
            0, // no receiver value needed
            GAS_LIMIT
        );
    }

```

A key part of this system, though, is that the contract at the `targetAddress` must implement the `IWormholeReceiver` interface.

Since we want to allow sending and receiving messages by the `HelloWormhole` contract, we must implement this interface.

```solidity
// SPDX-License-Identifier: Apache 2

pragma solidity ^0.8.0;

/**
 * @notice Interface for a contract which can receive Wormhole messages.
 */
interface IWormholeReceiver {
    /**
     * @notice When a `send` is performed with this contract as the target, this function will be
     *     invoked by the WormholeRelayer contract
     *
     * NOTE: This function should be restricted such that only the Wormhole Relayer contract can call it.
     *
     * We also recommend that this function checks that `sourceChain` and `sourceAddress` are indeed who
     *       you expect to have requested the calling of `send` on the source chain
     *
     * The invocation of this function corresponding to the `send` request will have msg.value equal
     *   to the receiverValue specified in the send request.
     *
     * If the invocation of this function reverts or exceeds the gas limit
     *   specified by the send requester, this delivery will result in a `ReceiverFailure`.
     *
     * @param payload - an arbitrary message which was included in the delivery by the
     *     requester.
     * @param additionalVaas - Additional VAAs which were requested to be included in this delivery.
     *   They are guaranteed to all be included and in the same order as was specified in the
     *     delivery request.
     * @param sourceAddress - the (wormhole format) address on the sending chain which requested
     *     this delivery.
     * @param sourceChain - the wormhole chain ID where this delivery was requested.
     * @param deliveryHash - the VAA hash of the deliveryVAA.
     *
     * NOTE: These signedVaas are NOT verified by the Wormhole core contract prior to being provided
     *     to this call. Always make sure `parseAndVerify()` is called on the Wormhole core contract
     *     before trusting the content of a raw VAA, otherwise the VAA may be invalid or malicious.
     */
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory additionalVaas,
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 deliveryHash
    ) external payable;
}
```

After `sendPayloadToEvm` is called on the source chain, the off-chain Delivery Provider will pick up the VAA corresponding to the message. It will then call the `receiveWormholeMessages` method on the `targetChain` and `targetAddress` specified.

So, in receiveWormholeMessages, we want to:

1. Update the latest greeting
2. Emit a 'GreetingReceived' event with the 'greeting' and sender of the greeting

> Note: It is crucial that only the Wormhole Relayer contract can call receiveWormholeMessages

To provide certainty about the validity of the payload, we must restrict the msg.sender of this function to only be the Wormhole Relayer contract. Otherwise, anyone could call this receiveWormholeMessages endpoint with fake greetings, source chains, and source senders.

And voila, we have a full contract that can be deployed to many EVM chains, and in totality would form a full cross-chain application powered by Wormhole!

Users with any wallet can request greetings to be emitted on any chain that is part of the system.

### How does it work?

[Check out Part 2](./hello-wormhole-explained.md) for an in-depth explanation of how Wormhole Relayer causes contracts on other blockchains to be called with the appropriate inputs!

### Full Cross-chain HelloWormhole solidity contract

See the [full implementation of the HelloWormhole.sol contract](https://github.com/wormhole-foundation/hello-wormhole/blob/main/src/HelloWormhole.sol) and the [full Github repository with testing infrastructure](https://github.com/wormhole-foundation/hello-wormhole/)
