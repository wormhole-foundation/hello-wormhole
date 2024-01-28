import {
  CONFIG,
  Chain,
  toChain,
  toChainId,
} from "@wormhole-foundation/connect-sdk";
import "@wormhole-foundation/connect-sdk-evm-core";
import { readFileSync, writeFileSync } from "fs";

export const NETWORK = "Testnet";
export const CHAINS: Chain[] = ["Avalanche", "Celo"];
export const NetworkConfig = CONFIG[NETWORK];

let _config: Config | undefined;
let _deployed: DeployedAddresses | undefined;

export interface ChainInfo {
  chain: Chain;
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

export function loadConfig(): Config {
  _config = _config ?? { chains: CHAINS.map((chain) => getChainInfo(chain)) };
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

export function getChainInfo(c: number | Chain): ChainInfo {
  const chain = typeof c === "number" ? toChain(c) : c;
  const chainId = toChainId(chain);
  const conf = NetworkConfig.chains[chain]!;
  const info: ChainInfo = {
    chain,
    chainId,
    description: `${chain}:${conf.network}`,
    rpc: conf.rpc,
    tokenBridge: conf.contracts.tokenBridge!,
    wormholeRelayer: conf.contracts.relayer!,
    wormhole: conf.contracts.coreBridge!,
  };

  return info;
}
