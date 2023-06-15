import { HelloWormhole__factory } from "./ethers-contracts"
import {
  loadConfig,
  getWallet,
  storeDeployedAddresses,
  getChain,
  loadDeployedAddresses,
} from "./utils"

export async function deploy() {
  const config = loadConfig()

  const deployed = loadDeployedAddresses()
  for (const chainId of config.chains.map(c => c.chainId)) {
    const chain = getChain(chainId)
    const signer = getWallet(chainId)

    const helloWormhole = await new HelloWormhole__factory(signer).deploy(
      chain.wormholeRelayer
    )
    await helloWormhole.deployed()

    deployed.helloWormhole[chainId] = helloWormhole.address
    
    console.log(
      `HelloWormhole deployed to ${helloWormhole.address} on ${chain.description} (chain ${chainId})`
    )
  }

  storeDeployedAddresses(deployed)
}
