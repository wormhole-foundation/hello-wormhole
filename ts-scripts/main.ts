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
    let greetings: string[] = []
    const helloWormhole = getHelloWormhole(chainId)
    while (true) {
      try {
        let greeting = await helloWormhole.greetings(i)
        greetings.push(greeting)
        i++
      } catch (error) {
        // Assuming the error is because we've reached the end of the array
        // This is not a great way to check this, and it won't always work
        break
      }
    }

    s += `chain ${chainId}:\n`
    for (const greeting of greetings) {
      s += `\n  ${greeting}`
    }
    s += "\n"
  }
  console.log(s)
}

main().catch(e => {
  console.error(e)
  process.exit(1)
})
