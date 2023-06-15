Hello Wormhole
--------------

This repository contains a single contract to demonstrate a minimal xDapp using Automatic Relaying to pass arbitrary messages to different chains. 

A Full tutorial is available [here](https://docs.wormhole.com/wormhole/guide/tutorials/event-horizon/hello-universe)

## Description

The `HelloWormhole.sol` contract implements the `IWormholeReceiver` interface so that it may receive messages from the relayer when its `receiveWormholeMessage` function is called. 

It also implements a method `sendCrossChainGreeting` that:

1) requests a quote from the relayer for the amount of gas it expects to use
2) calls the relayer, passing the message and estimated gas cost
3) refunds any overpayment from the sender that was not used to cover gas

## Concepts

Concepts covered:

- Quote cost to relay message
- Calling into relayer (relayer calls core bridge)
- Receiving a message from relayer (VAA _not_ validated by bridge)
- Refunding overpayment of value sent

Concepts not covered:

- Replay protection
- Message Ordering
- Additional VAAs
- Fowarding/Call Chaining
- Refunding overpayment of gasLimit

## Run it

Ensure you have [forge](https://book.getfoundry.sh/getting-started/installation) installed

Clone this repository down and cd into it

```sh
git clone https://github.com/JoeHowarth/hello-wormhole
cd hello-wormhole
```

install dependencies and build the project

```sh
yarn
yarn build
```

Run the unit tests

```sh
forge test
```

## Testing

This project introduces a novel way to use Forge's fork testing

Specifically, in `test/HelloWormhole.t.sol` we setup a pair of forks that represent separate blockchains. By using the individual forks to send and recieve messages we can test the logic of our smart contracts without dealing with the issues related to the messages being relayed off chain. 