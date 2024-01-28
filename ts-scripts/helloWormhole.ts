import {
  Chain,
  ChainAddress,
  Network,
  canonicalAddress,
  nativeChainIds,
  toChainId,
} from "@wormhole-foundation/connect-sdk";
import {
  EvmChains,
  EvmPlatform,
  EvmUnsignedTransaction,
  addChainId,
} from "@wormhole-foundation/connect-sdk-evm";
import { Provider, TransactionRequest } from "ethers";
import { HelloWormhole, HelloWormhole__factory } from "./ethers-contracts";

export class HelloWormholeClient<N extends Network, C extends EvmChains> {
  readonly helloWormhole: HelloWormhole;
  readonly helloWormholeAddress: string;
  readonly chainId: bigint;

  constructor(
    readonly network: N,
    readonly chain: C,
    readonly provider: Provider,
    readonly address: string
  ) {
    this.chainId = nativeChainIds.networkChainToNativeChainId.get(
      network,
      chain
    ) as bigint;

    this.helloWormholeAddress = address;
    this.helloWormhole = HelloWormhole__factory.connect(
      this.helloWormholeAddress,
      provider
    );
  }

  static async fromRpc<N extends Network>(
    provider: Provider,
    address: string
  ): Promise<HelloWormholeClient<N, EvmChains>> {
    const [network, chain] = await EvmPlatform.chainFromRpc(provider);
    return new HelloWormholeClient(network as N, chain, provider, address);
  }

  async quoteCrossChainGreeting(to: Chain): Promise<bigint> {
    return await this.helloWormhole.quoteCrossChainGreeting(toChainId(to));
  }

  async latestGreeting(): Promise<string> {
    return await this.helloWormhole.latestGreeting();
  }

  async *sendCrossChainGreeting(
    to: ChainAddress,
    message: string,
    value?: bigint
  ): AsyncGenerator<EvmUnsignedTransaction<N, C>> {
    if (!value) {
      value = await this.quoteCrossChainGreeting(to.chain);
    }

    const tx =
      await this.helloWormhole.sendCrossChainGreeting.populateTransaction(
        toChainId(to.chain),
        canonicalAddress(to),
        message,
        { value }
      );

    yield this.createUnsignedTx(tx, "HelloWormhole.SendCrossChainGreeting");
  }

  private createUnsignedTx(
    txReq: TransactionRequest,
    description: string,
    parallelizable: boolean = false
  ): EvmUnsignedTransaction<N, C> {
    return new EvmUnsignedTransaction(
      addChainId(txReq, this.chainId),
      this.network,
      this.chain,
      description,
      parallelizable
    );
  }
}
