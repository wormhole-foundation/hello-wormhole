import { describe, expect, test } from "@jest/globals";
import {
  Wormhole,
  signSendWait,
  toChain,
} from "@wormhole-foundation/connect-sdk";
import { EvmChains } from "@wormhole-foundation/connect-sdk-evm";
import { ethers } from "ethers";
import {
  getHelloWormholeClient,
  getSigner,
  getStatus,
  getWormhole,
} from "./utils";

const sourceChain = 6;
const targetChain = 14;

describe("Hello Wormhole Integration Tests on Testnet", () => {
  test(
    "Tests the sending of a random greeting",
    async () => {
      const wh = getWormhole();
      const srcChain = wh.getChain(toChain(sourceChain));
      const tgtChain = wh.getChain(toChain(targetChain));

      const arbitraryGreeting = `Hello Wormhole ${new Date().getTime()}`;
      const srcHelloWormhole = getHelloWormholeClient(sourceChain);
      const tgtHelloWormhole = getHelloWormholeClient(targetChain);

      const cost = await srcHelloWormhole.quoteCrossChainGreeting(
        tgtChain.chain
      );
      console.log(
        `Cost of sending the greeting: ${ethers.formatEther(cost)} testnet AVAX`
      );

      console.log(`Sending greeting: ${arbitraryGreeting}`);
      const txReq = srcHelloWormhole.sendCrossChainGreeting(
        Wormhole.chainAddress(tgtChain.chain, tgtHelloWormhole.address),
        arbitraryGreeting
      );

      const [txid] = await signSendWait(
        srcChain,
        txReq,
        await getSigner(srcChain.chain)
      );

      console.log(`Transaction hash: ${txid.txid}`);

      await waitForDelivery(toChain(sourceChain) as EvmChains, txid.txid);

      console.log(`Reading greeting`);
      const readGreeting = await tgtHelloWormhole.latestGreeting();
      console.log(`Latest greeting: ${readGreeting}`);
      expect(readGreeting).toBe(arbitraryGreeting);
    },
    60 * 1000 * 60
  ); // timeout
});

const waitForDelivery = async (
  sourceChain: EvmChains,
  transactionHash: string
) => {
  let pastStatusString = "";
  let waitCount = 0;
  while (true) {
    let waitTime = 15;
    if (waitCount > 5) {
      waitTime = 60;
    }
    await new Promise((resolve) => setTimeout(resolve, 1000 * waitTime));
    waitCount += 1;

    const res = await getStatus(sourceChain, transactionHash);
    if (res.info !== pastStatusString) {
      console.log(res.info);
      pastStatusString = res.info;
    }
    if (res.status !== "Pending") break;
    console.log(`\nContinuing to wait for delivery\n`);
  }
};
