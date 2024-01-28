import { ethers, Wallet } from "ethers";
import { HelloWormhole, HelloWormhole__factory } from "./ethers-contracts";
import {
  Chain,
  toChain,
  Signer,
  Wormhole,
  toChainId,
} from "@wormhole-foundation/connect-sdk";
import {
  EvmChains,
  EvmPlatform,
  getEvmSignerForKey,
} from "@wormhole-foundation/connect-sdk-evm";
import { loadDeployedAddresses, NETWORK, NetworkConfig } from "./config";

import "@wormhole-foundation/connect-sdk-evm-core";
import { HelloWormholeClient } from "./helloWormhole";

// read in from `.env`
require("dotenv").config();
function getEnv(key: string): string {
  if (typeof process === undefined) return "";
  if (!(key in process.env))
    throw `Missing env var ${key}, did you forget to set values in '.env'?`;
  return process.env[key]!;
}

export const getEvmKey = (): string => getEnv("EVM_PRIVATE_KEY");

export const getSigner = async (chain: Chain): Promise<Signer> =>
  await getEvmSignerForKey(getRpc(toChainId(chain)), getEvmKey());

export const getRpc = (chainId: number): ethers.Provider =>
  new ethers.JsonRpcProvider(NetworkConfig.chains[toChain(chainId)]?.rpc);

export const getWallet = (chainId: number): Wallet =>
  new Wallet(getEvmKey(), getRpc(chainId));

export const getWormhole = (): Wormhole<typeof NETWORK> =>
  new Wormhole(NETWORK, [EvmPlatform]);

export const getHelloWormhole = (chainId: number): HelloWormhole =>
  getHelloWormholeClient(chainId).helloWormhole;

export const getHelloWormholeClient = (
  chainId: number
): HelloWormholeClient<typeof NETWORK, EvmChains> =>
  new HelloWormholeClient(
    NETWORK,
    toChain(chainId) as EvmChains,
    getRpc(chainId),
    loadDeployedAddresses().helloWormhole[chainId]
  );

export async function getStatus(
  sourceChain: EvmChains,
  txid: string
): Promise<{ status: string; info: string }> {
  const wh = getWormhole();
  const ctx = wh.getChain(sourceChain);
  const [msgid] = await ctx.parseTransaction(txid);

  const info = await wh.getTransactionStatus(msgid!);
  const status = info?.globalTx?.originTx.status || "Pending";
  return { status, info: JSON.stringify(info) || "Info not obtained" };
}

export function checkSubcommand(patterns: string | string[]) {
  if ("string" === typeof patterns) {
    patterns = [patterns];
  }
  return patterns.includes(process.argv[2]);
}

export function checkFlag(patterns: string | string[]) {
  return getArg(patterns, { required: false, isFlag: true });
}

export function getArg(
  patterns: string | string[],
  {
    isFlag = false,
    required = true,
  }: { isFlag?: boolean; required?: boolean } = {
    isFlag: false,
    required: true,
  }
): string | undefined {
  let idx: number = -1;
  if (typeof patterns === "string") {
    patterns = [patterns];
  }
  for (const pattern of patterns) {
    idx = process.argv.findIndex((x) => x === pattern);
    if (idx !== -1) {
      break;
    }
  }
  if (idx === -1) {
    if (required) {
      throw new Error(
        "Missing required cmd line arg: " + JSON.stringify(patterns)
      );
    }
    return undefined;
  }
  if (isFlag) {
    return process.argv[idx];
  }
  return process.argv[idx + 1];
}
