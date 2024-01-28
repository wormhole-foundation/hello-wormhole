import * as ethers from "ethers";
import {
  getChainInfo,
  loadConfig,
  loadDeployedAddresses,
  storeDeployedAddresses,
} from "./config";
import {
  checkFlag,
  checkSubcommand,
  getArg,
  getHelloWormhole,
  getStatus,
  getWallet,
} from "./utils";

import { HelloWormhole__factory } from "./ethers-contracts";

import "@wormhole-foundation/connect-sdk-evm-core";

async function main() {
  if (checkSubcommand("sendGreeting")) {
    await sendGreeting();
    return;
  }
  if (checkSubcommand("deploy")) {
    await deploy();
    return;
  }
  if (checkSubcommand("read")) {
    await read();
    return;
  }
  if (checkFlag("--getStatus")) {
    const status = await getStatus(
      "Avalanche",
      getArg(["--txHash", "--tx", "-t"]) || ""
    );
    console.log(status.info);
  }
}

export async function deploy() {
  const config = loadConfig();

  const deployed = loadDeployedAddresses();
  for (const chainId of config.chains.map((c) => c.chainId)) {
    const chain = getChainInfo(chainId);
    const signer = getWallet(chainId);
    const helloWormhole = await new HelloWormhole__factory(signer).deploy(
      chain.wormholeRelayer
    );
    await helloWormhole.waitForDeployment();
    const address = await helloWormhole.getAddress();

    deployed.helloWormhole[chainId] = address;

    console.log(
      `HelloWormhole deployed to ${address} on ${chain.description} (chain ${chainId})`
    );
  }

  storeDeployedAddresses(deployed);
}

async function sendGreeting() {
  // const from = Number(getArg(["--from", "-f"]))
  // const to = Number(getArg(["--to", "-t"]))

  const from = 6;
  const to = 14;
  const greeting = getArg(["--greeting", "-g"]) ?? "Hello, Wormhole!";

  const helloWormhole = getHelloWormhole(from);
  const cost = await helloWormhole.quoteCrossChainGreeting(to);
  console.log(`cost: ${ethers.formatEther(cost)}`);

  const tx = await helloWormhole.sendCrossChainGreeting(
    to,
    await getHelloWormhole(to).getAddress(),
    greeting,
    { value: cost }
  );
  await tx.wait();
  console.log(
    `Greeting "${greeting}" sent from chain ${from} to chain ${to}\nTransaction hash ${tx.hash}\nView Transaction at https://testnet.snowtrace.io/tx/${tx.hash}`
  );
}

async function read(s = "State: \n\n") {
  for (const chainId of loadConfig().chains.map((c) => c.chainId)) {
    const helloWormhole = getHelloWormhole(chainId);
    const greeting = await helloWormhole.latestGreeting();
    s += `chain ${chainId}: ${greeting}\n`;
    s += "\n";
  }
  console.log(s);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
