import { ethers, Wallet } from "ethers"
import { readFileSync, writeFileSync } from "fs"

export interface ChainInfo {
  description: string
  chainId: number
  rpc: string
  tokenBridge: string
  wormholeRelayer: string
  wormhole: string
}

export interface Config {
  chains: ChainInfo[]
}
export interface DeployedAddresses {
  helloTokens: Record<number, string>
  erc20s: Record<number, string[]>
}

export function getChain(chainId: number): ChainInfo {
  const chain = loadConfig().chains.find(c => c.chainId === chainId)!
  if (!chain) {
    throw new Error(`Chain ${chainId} not found`)
  }
  return chain
}

export function getWallet(chainId: number): Wallet {
  const rpc = loadConfig().chains.find(c => c.chainId === chainId)?.rpc
  let provider = new ethers.providers.JsonRpcProvider(rpc)
  return new Wallet(process.env.EVM_PRIVATE_KEY!, provider)
}

let _config: Config | undefined
let _deployed: DeployedAddresses | undefined

export function loadConfig(): Config {
  if (!_config) {
    _config = JSON.parse(
      readFileSync("ts-scripts/testnet/config.json", { encoding: "utf-8" })
    )
  }
  return _config!
}

export function loadDeployedAddresses(): DeployedAddresses {
  if (!_deployed) {
    _deployed = JSON.parse(
      readFileSync("ts-scripts/testnet/deployedAddresses.json", {
        encoding: "utf-8",
      })
    )
    if (!deployed) {
      _deployed = {
        erc20s: [],
        helloTokens: [],
      }
    }
  }
  return _deployed!
}

export function storeDeployedAddresses(deployed: DeployedAddresses) {
  writeFileSync(
    "ts-scripts/testnet/deployedAddresses.json",
    JSON.stringify(deployed, undefined, 2)
  )
}

export function checkFlag(patterns: string | string[]) {
  return getArg(patterns, { required: false, isFlag: true })
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
  let idx: number = -1
  if (typeof patterns === "string") {
    patterns = [patterns]
  }
  for (const pattern of patterns) {
    idx = process.argv.findIndex(x => x === pattern)
    if (idx !== -1) {
      break
    }
  }
  if (idx === -1) {
    if (required) {
      throw new Error(
        "Missing required cmd line arg: " + JSON.stringify(patterns)
      )
    }
    return undefined
  }
  if (isFlag) {
    return process.argv[idx]
  }
  return process.argv[idx + 1]
}

export const deployed = (x: any) => x.deployed()
export const wait = (x: any) => x.wait()
