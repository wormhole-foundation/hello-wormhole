import { ethers, Wallet } from "ethers";
import { readFileSync, writeFileSync } from "fs";

import { HelloWormhole, HelloWormhole__factory } from "./ethers-contracts";

import {
  EvmNativeSigner,
  EvmPlatform,
  getEvmSignerForKey,
} from "@wormhole-foundation/connect-sdk-evm";
import {
  Chain,
  CONFIG,
  Network,
  Signer,
  toChain,
  Wormhole,
} from "@wormhole-foundation/connect-sdk";

// read in from `.env`
require("dotenv").config();

function getEnv(key: string): string {
  // If we're in the browser, return empty string
  if (typeof process === undefined) return "";
  // Otherwise, return the env var or error
  const val = process.env[key];
  if (!val)
    throw new Error(
      `Missing env var ${key}, did you forget to set valies in '.env'?`
    );
  return val;
}

export async function getSigner<N extends Network, C extends Chain>(
  network: N,
  chain: C
): Promise<Signer> {
  const wh = new Wormhole(network, [EvmPlatform]);
  const ctx = wh.getChain(chain);
  return await getEvmSignerForKey(
    await ctx.getRpc(),
    getEnv("ETH_PRIVATE_KEY")
  );
}

export interface ChainInfo {
  description: string;
  chainId: number;
  rpc: string;
  tokenBridge: string;
  wormholeRelayer: string;
  wormhole: string;
}

export interface Config {
  chains: ChainInfo[];
}
export interface DeployedAddresses {
  helloWormhole: Record<number, string>;
  erc20s: Record<number, string[]>;
}

export function getHelloWormhole(chainId: number): HelloWormhole {
  const deployed = loadDeployedAddresses().helloWormhole[chainId];
  if (!deployed) {
    throw new Error(`No deployed hello wormhole on chain ${chainId}`);
  }
  return HelloWormhole__factory.connect(deployed, getWallet(chainId));
}

export function getChain(network: Network, chainId: number): ChainInfo {
  const chain = toChain(chainId);

  const conf = CONFIG[network].chains[chain]!;
  const info: ChainInfo = {
    description: `${network}:${chain}`,
    chainId,
    rpc: conf.rpc,
    tokenBridge: conf.contracts.tokenBridge!,
    wormholeRelayer: conf.contracts.relayer!,
    wormhole: conf.contracts.coreBridge!,
  };

  return info;
}

export function getWallet(chainId: number): Wallet {
  const rpc = loadConfig().chains.find((c) => c.chainId === chainId)?.rpc;
  let provider = new ethers.JsonRpcProvider(rpc);
  if (!process.env.EVM_PRIVATE_KEY)
    throw Error(
      "No private key provided (use the EVM_PRIVATE_KEY environment variable)"
    );
  return new Wallet(process.env.EVM_PRIVATE_KEY!, provider);
}

let _config: Config | undefined;
let _deployed: DeployedAddresses | undefined;

export function loadConfig(): Config {
  if (!_config) {
    _config = JSON.parse(
      readFileSync("ts-scripts/testnet/config.json", { encoding: "utf-8" })
    );
  }
  return _config!;
}

export function loadDeployedAddresses(
  fileMustBePresent?: "fileMustBePresent"
): DeployedAddresses {
  if (!_deployed) {
    try {
      _deployed = JSON.parse(
        readFileSync("ts-scripts/testnet/deployedAddresses.json", {
          encoding: "utf-8",
        })
      );
    } catch (e) {
      if (fileMustBePresent) {
        throw e;
      }
    }
    if (!_deployed) {
      _deployed = {
        erc20s: [],
        helloWormhole: [],
      };
    }
  }
  return _deployed!;
}

export function storeDeployedAddresses(deployed: DeployedAddresses) {
  writeFileSync(
    "ts-scripts/testnet/deployedAddresses.json",
    JSON.stringify(deployed, undefined, 2)
  );
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

export const deployed = (x: any) => x.deployed();
export const wait = (x: any) => x.wait();

export const sleep = (ms: number) =>
  new Promise((resolve) => setTimeout(resolve, ms));
