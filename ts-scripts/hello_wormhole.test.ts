import { describe, expect, test } from "@jest/globals";
import { toChain } from "@wormhole-foundation/connect-sdk";
import { ethers } from "ethers";
import { waitForDelivery } from "./getStatus";
import { getHelloWormhole } from "./utils";

const sourceChain = 6;
const targetChain = 14;

import "@wormhole-foundation/connect-sdk-evm-core";

describe("Hello Wormhole Integration Tests on Testnet", () => {
  test(
    "Tests the sending of a random greeting",
    async () => {
      const arbitraryGreeting = `Hello Wormhole ${new Date().getTime()}`;
      const sourceHelloWormholeContract = getHelloWormhole(sourceChain);
      const targetHelloWormholeContract = getHelloWormhole(targetChain);

      const cost = await sourceHelloWormholeContract.quoteCrossChainGreeting(
        targetChain
      );
      console.log(
        `Cost of sending the greeting: ${ethers.formatEther(cost)} testnet AVAX`
      );

      console.log(`Sending greeting: ${arbitraryGreeting}`);
      const tx = await sourceHelloWormholeContract.sendCrossChainGreeting(
        targetChain,
        await targetHelloWormholeContract.getAddress(),
        arbitraryGreeting,
        { value: cost }
      );
      console.log(`Transaction hash: ${tx.hash}`);
      const rx = await tx.wait();

      await waitForDelivery(toChain(sourceChain), tx.hash);

      console.log(`Reading greeting`);
      const readGreeting = await targetHelloWormholeContract.latestGreeting();
      console.log(`Latest greeting: ${readGreeting}`);
      expect(readGreeting).toBe(arbitraryGreeting);
    },
    60 * 1000 * 60
  ); // timeout
});
