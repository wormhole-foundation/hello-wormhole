import {
  loadConfig,
  getWallet,
  storeDeployedAddresses,
  getChain,
  loadDeployedAddresses,
} from "./utils";
import { relayer, ChainName } from "@certusone/wormhole-sdk";

export async function getStatus(
  sourceChain: ChainName,
  transactionHash: string
): Promise<{ status: string; info: string }> {
  const info = await relayer.getWormholeRelayerInfo(
    sourceChain,
    transactionHash,
    { environment: "TESTNET" }
  );
  const status =
    info.targetChainStatus.events[0]?.status || DeliveryStatus.PendingDelivery;
  return { status, info: info.stringified || "Info not obtained" };
}

export const DeliveryStatus = relayer.DeliveryStatus;

export const waitForDelivery = async (
  sourceChain: ChainName,
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
    if (res.status !== DeliveryStatus.PendingDelivery) break;
    console.log(`\nContinuing to wait for delivery\n`);
  }
};
