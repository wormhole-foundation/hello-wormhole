import { Chain, Wormhole, api } from "@wormhole-foundation/connect-sdk";
import { EvmPlatform } from "@wormhole-foundation/connect-sdk-evm";

export async function getStatus(
  sourceChain: Chain,
  txid: string
): Promise<{ status: string; info: string }> {
  const wh = new Wormhole("Testnet", [EvmPlatform]);
  const ctx = wh.getChain(sourceChain);
  const [msgid] = await ctx.parseTransaction(txid);

  const info = await wh.getTransactionStatus(msgid!);
  const status = info?.globalTx?.originTx.status || "Pending";
  return { status, info: JSON.stringify(info) || "Info not obtained" };
}

export const waitForDelivery = async (
  sourceChain: Chain,
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
