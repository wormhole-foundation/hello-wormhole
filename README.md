# Building Your First Cross-Chain Application

This repository contains a solidity contract (HelloWormhole.sol) that can be deployed onto many EVM chains to form a fully functioning cross-chain application.

Specifically, we will write and deploy a contract onto many chains that allows users to request, from one contract, for a GreetingReceived event to be emitted from one of the other contracts on a different chain. 

This allows users to pay for their custom greeting to be emitted on a chain that they do not have any gas funds for! 

## Getting Started

Included in this repository is:

- Example Solidity Code
- Example Forge local testing setup
- Testnet Deploy Scripts
- Example Testnet testing setup

### Environment Setup

- Node 18.9.1 or later, npm 8.19.1 or later: [https://docs.npmjs.com/downloading-and-installing-node-js-and-npm](https://docs.npmjs.com/downloading-and-installing-node-js-and-npm)
- forge 0.2.0 or later: [https://book.getfoundry.sh/getting-started/installation](https://book.getfoundry.sh/getting-started/installation)

### Testing Locally

```bash
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

This single-chain HelloWorld smart contract allows users to send greetings, a.k.a allows them to cause an event ‘GreetingReceived’ to be emitted with their greeting!

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

Suppose we want users to be able to request through their Ethereum wallet for a greeting to be sent to Avalanche, and vice versa. Let us begin writing a contract that we can deploy onto Ethereum, Avalanche, and any number of other chains, and enable greetings to be sent freely to and from each contract irrespective of chain. 

We’d want to implement the following function: 

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

The Wormhole Relayer network is powered by ******************Delivery Providers******************, who perform the service of watching for Wormhole Relayer delivery requests and performing the delivery to the intended target chain as instructed. 

In exchange for calling your contract at ‘targetAddress’ on ‘targetChain’ and paying the gas fees that your contract uses up, they charge a source chain fee of 

`(deliveryPrice,) = quoteEVMDeliveryPrice(targetChain, receiverValue, gasLimit)`

So, following this interface, we can implement `sendCrossChainGreeting` by simply calling sendPayloadToEvm with the payload being the greeting.

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
        bytes memory payload = abi.encode(greeting);
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

A key part of this system though is that ‘targetAddress’ must implement the IWormholeReceiver interface! Since we want to be able to send both to and from the HelloWormhole contract, we must implement this interface. 

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
     * We also recommend that this function:
     *   - Stores all received `deliveryHash`s in a mapping `(bytes32 => bool)`, and
     *       on every call, checks that deliveryHash has not already been stored in the
     *       map (This is to prevent other users maliciously trying to relay the same message)
     *   - Checks that `sourceChain` and `sourceAddress` are indeed who
     *       you expect to have requested the calling of `send` or `forward` on the source chain
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

What will happen is, when on the source chain ‘sendPayloadToEvm’ is called, the  Delivery Provider will watch the source chain and then call the ‘receiveWormholeMessages’ endpoint on the targetChain and targetAddress specified. So, in receiveWormholeMessages, we want to 

- Update the latest greeting
- Emit a 'GreetingReceived' event with the 'greeting'

```solidity
	event GreetingReceived(string greeting, uint16 senderChain, address sender);

    string public latestGreeting;

    /**
     * @notice Endpoint that the Wormhole Relayer contract will call
     * to deliver the greeting
     */
    function receiveWormholeMessages(
        bytes memory payload,
        bytes[] memory, // additionalVaas
        bytes32 sourceAddress,
        uint16 sourceChain,
        bytes32 // deliveryHash
    ) public payable override {
        require(msg.sender == address(wormholeRelayer), "Only relayer allowed");

        latestGreeting = abi.decode(payload, (string));

        emit GreetingReceived(
            latestGreeting,
            sourceChain,
            fromWormholeFormat(sourceAddress)
        );
    }
```

**Note 1:** It is crucial that only the Wormhole Relayer contract can call receiveWormholeMessages

To be able to have any certainty about the validity of the payload, we must restrict the msg.sender of this function to only be the Wormhole Relayer contract. Otherwise, anyone could call this receiveWormholeMessages endpoint with fake greetings, source chains, and source senders. 

**Note 2:** Wormhole left-pads EVM addresses into a bytes32 format, to allow for compatibility with ecosystems that don't have 20-byte addresses. We use a helper 'fromWormholeFormat' here to obtain the address in 20-byte format (discarding the first 12 bytes).
    
```solidity
    // Helper to convert 32-byte Wormhole formatted address to a standard EVM address
    function fromWormholeFormat(bytes32 whFormatAddress) pure returns (address) {
    	if (uint256(whFormatAddress) >> 160 != 0)
    		revert NotAnEvmAddress(whFormatAddress);
    	return address(uint160(uint256(whFormatAddress)));
    }
```
    

And voila, we have a full contract that can be deployed to many EVM chains, and in totality would form a full cross-chain application powered by Wormhole!

Users with any wallet can request greetings to be emitted on any chain that is part of the system. 

### How does it work?

[Check out Part 2](HOW_DOES_IT_WORK.md) for an in-depth explanation of how Wormhole Relayer causes contracts on other blockchains to be called with the appropriate inputs!

### Full Cross-chain HelloWormhole solidity contract

**Full Github Repository with Testing infrastructure here: [https://github.com/JoeHowarth/hello-wormhole/blob/main/src/HelloWormhole.sol](https://github.com/JoeHowarth/hello-wormhole/blob/main/src/HelloWormhole.sol)**

