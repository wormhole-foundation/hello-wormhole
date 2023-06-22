import {
  loadConfig,
  getWallet,
  storeDeployedAddresses,
  getChain,
  loadDeployedAddresses,
} from "./utils"
import {relayer, ChainName} from "@certusone/wormhole-sdk"

export async function getStatus(sourceChain: ChainName, transactionHash: string): Promise<{status: string, info: string}> {
  const info = await relayer.getWormholeRelayerInfo(sourceChain, transactionHash, {environment: "TESTNET"});
  const status = info.targetChainStatus.events[0].status;
  return {status, info: relayer.stringifyWormholeRelayerInfo(info)};
}
