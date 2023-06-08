import { ethers } from "ethers"
import { HelloTokens__factory, ERC20Mock__factory } from "./ethers-contracts"
import {
  loadConfig,
  getWallet,
  storeDeployedAddresses,
  getChain,
  wait,
  loadDeployedAddresses,
} from "./utils"

export async function deploy() {
  const config = loadConfig()

  // fuij and celo
  const deployed = loadDeployedAddresses()
  for (const chainId of [6, 14]) {
    const chain = getChain(chainId)
    const signer = getWallet(chainId)

    const helloTokens = await new HelloTokens__factory(signer).deploy(
      chain.wormholeRelayer,
      chain.tokenBridge!,
      chain.wormhole
    )
    await helloTokens.deployed()

    deployed.helloTokens[chainId] = helloTokens.address
    console.log(
      `HelloTokens deployed to ${helloTokens.address} on chain ${chainId}`
    )
  }

  storeDeployedAddresses(deployed)
}

