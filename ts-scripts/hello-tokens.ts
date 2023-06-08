import { ethers } from "ethers"
import { HelloTokens__factory, HelloTokens } from "./types"
import * as fs from "fs/promises"

export type ChainInfo = {
  evmNetworkId: number
  chainId: number
  rpc: string
  wormholeAddress: string
  tokenBridge?: string
}

export type Deployment = {
  chainId: number
  address: string
}

async function main() {
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!)
  const chains = await loadJsonFile<{ chains: ChainInfo[] }>(
    "./ts-scripts/testnet/chains.json"
  )
  const contracts = await loadJsonFile<any>(
    "./ts-scripts/testnet/contracts.json"
  )
  const helloTokensAddresses = await loadJsonFile<Record<number, string>>("./ts-scripts/testnet/helloTokens.json")

  const helloTokensFuji = await new HelloTokens__factory(wallet).attach(helloTokensAddresses[6])
  const cost = await helloTokensFuji.quoteRemoteLP(14)
  helloTokensFuji.sendRemoteLP(14, helloTokensAddresses[14], 0,  cost)

  // fuij and celo
  const deployed: Record<number, string> = {} as any
  for (const chainId of [6]) {
    const chain = chains.chains.find(chain => chain.chainId === chainId)
    if (!chain) {
      throw new Error(`Chain ${chainId} not found`)
    }
    const provider = new ethers.providers.JsonRpcProvider(chain.rpc)
    const signer = wallet.connect(provider)

    const helloTokens = await new HelloTokens__factory(signer).deploy(
      contracts.wormholeRelayers.find((x: Deployment) => x.chainId === chainId)!
        .address,
      chain.tokenBridge!,
      chain.wormholeAddress
    )
    await helloTokens.deployed()
    deployed[chainId] = helloTokens.address
    console.log(
      `HelloTokens deployed to ${helloTokens.address} on chain ${chainId}`
    )
  }

  await fs.writeFile(
    "./ts-scripts/testnet/helloTokens.json",
    JSON.stringify(deployed, null, 2),
  )
}

async function loadJsonFile<T>(path: string): Promise<T> {
  const file = await fs.readFile(path, "utf-8")
  return JSON.parse(file)
}

main().catch(error => {
  console.error(error)
  process.exitCode = 1
})
