import * as ethers from "ethers"
import {
  checkFlag,
  loadDeployedAddresses as getDeployedAddresses,
  getWallet,
  wait,
} from "./utils"
import { ERC20Mock__factory, HelloTokens__factory } from "./ethers-contracts"
import { deploy } from "./deploy"
import { deployMockTokens } from "./deploy-mock-tokens"

async function main() {
  if (checkFlag("--sendRemoteLP")) {
    await sendRemoteLP()
    return
  }
  if (checkFlag("--deployHelloTokens")) {
    await deploy()
    return
  }
  if (checkFlag("--deployMockTokens")) {
    await deployMockTokens()
    return
  }

  // await read();
}

async function sendRemoteLP() {
  // const from = Number(getArg(["--from", "-f"]))
  // const to = Number(getArg(["--to", "-t"]))
  // const amount = getArg(["--amount", "-a"])

  const from = 6
  const to = 14
  const amount = ethers.utils.parseEther("10")

  const helloToken = getHelloToken(from)
  const cost = await helloToken.quoteRemoteLP(to)
  console.log(`cost: ${ethers.utils.formatEther(cost)}`)

  const [HT, GbT] = getDeployedAddresses().erc20s[from].map(erc20 =>
    ERC20Mock__factory.connect(erc20, getWallet(from))
  )

  const rx = await helloToken
    .sendRemoteLP(
      to,
      getHelloToken(to).address,
      amount,
      HT.address,
      GbT.address
    )
    .then(wait)
}

function getHelloToken(chainId: number) {
  const deployed = getDeployedAddresses().helloTokens[chainId]
  if (!deployed) {
    throw new Error(`No deployed hello token on chain ${chainId}`)
  }
  return HelloTokens__factory.connect(deployed, getWallet(chainId))
}

// async function read(s = "State: ") {
//   for (const deployed of getDeployedAddresses().counter) {
//     const counter = Counter__factory.connect(
//       deployed.address,
//       getWallet(deployed.chainId)
//     )
//     const number = await counter.getNumber()
//     s += `chain ${deployed.chainId}: ${number} `
//   }
//   console.log(s)
// }

main().catch(e => {
  console.error(e)
  process.exit(1)
})
