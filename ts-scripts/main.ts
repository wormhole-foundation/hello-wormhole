import * as ethers from "ethers"
import {
  checkFlag,
  checkSubcommand,
  getArg,
  loadDeployedAddresses as getDeployedAddresses,
  getWallet,
  loadConfig,
  wait,
} from "./utils"
import { HelloWormhole, HelloWormhole__factory } from "./ethers-contracts"
import { deploy } from "./deploy"

async function main() {
  console.log(process.argv)
  if (checkSubcommand("sendGreeting")) {
    await sendGreeting()
    return
  }
  if (checkSubcommand("deploy")) {
    await deploy()
    return
  }
  if (checkSubcommand("read")) {
    await read()
    return
  }
}

async function sendGreeting() {
  // const from = Number(getArg(["--from", "-f"]))
  // const to = Number(getArg(["--to", "-t"]))

  const from = 6
  const to = 14
  const greeting = getArg(["--greeting", "-g"]) ?? "Hello, Wormhole!"

  const helloWormhole = getHelloWormhole(from)
  const cost = await helloWormhole.quoteCrossChainGreeting(to)
  console.log(`cost: ${ethers.utils.formatEther(cost)}`)

  const rx = await helloWormhole
    .sendCrossChainGreeting(to, getHelloWormhole(to).address, greeting, {value: cost})
    .then(wait)
}

function getHelloWormhole(chainId: number): HelloWormhole {
  const deployed = getDeployedAddresses().helloWormhole[chainId]
  if (!deployed) {
    throw new Error(`No deployed hello wormhole on chain ${chainId}`)
  }
  return HelloWormhole__factory.connect(deployed, getWallet(chainId))
}

async function read(s = "State: \n\n") {
  for (const chainId of loadConfig().chains.map(c => c.chainId)) {
    let i = 0
    const helloWormhole = getHelloWormhole(chainId)
    const greeting = await helloWormhole.latestGreeting();
    s += `chain ${chainId}: ${greeting}\n`
    s += "\n"
  }
  console.log(s)
}

main().catch(e => {
  console.error(e)
  process.exit(1)
})
