import * as ethers from "ethers"
import {
  checkSubcommand,
  getArg,
  getHelloWormhole,
  loadConfig,
  checkFlag
} from "./utils"
import { deploy } from "./deploy"
import { getStatus } from "./getStatus"

async function main() {
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
  if(checkFlag("--getStatus")) {
    const status = await getStatus("avalanche", getArg(["--txHash", "--tx", "-t"]) || "");
    console.log(status.info);
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

  const tx = await helloWormhole
    .sendCrossChainGreeting(to, getHelloWormhole(to).address, greeting, {value: cost});
  await tx.wait();
  console.log(`Greeting "${greeting}" sent from chain ${from} to chain ${to}\nTransaction hash ${tx.hash}\nView Transaction at https://testnet.snowtrace.io/tx/${tx.hash}`)
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
