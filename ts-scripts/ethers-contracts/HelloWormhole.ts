/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumber,
  BigNumberish,
  BytesLike,
  CallOverrides,
  ContractTransaction,
  PayableOverrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import type {
  FunctionFragment,
  Result,
  EventFragment,
} from "@ethersproject/abi";
import type { Listener, Provider } from "@ethersproject/providers";
import type {
  TypedEventFilter,
  TypedEvent,
  TypedListener,
  OnEvent,
} from "./common";

export interface HelloWormholeInterface extends utils.Interface {
  functions: {
    "greetings(uint256)": FunctionFragment;
    "quoteCrossChainGreeting(uint16)": FunctionFragment;
    "receiveWormholeMessages(bytes,bytes[],bytes32,uint16,bytes32)": FunctionFragment;
    "sendCrossChainGreeting(uint16,address,string)": FunctionFragment;
    "wormholeRelayer()": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "greetings"
      | "quoteCrossChainGreeting"
      | "receiveWormholeMessages"
      | "sendCrossChainGreeting"
      | "wormholeRelayer"
  ): FunctionFragment;

  encodeFunctionData(
    functionFragment: "greetings",
    values: [BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "quoteCrossChainGreeting",
    values: [BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "receiveWormholeMessages",
    values: [BytesLike, BytesLike[], BytesLike, BigNumberish, BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "sendCrossChainGreeting",
    values: [BigNumberish, string, string]
  ): string;
  encodeFunctionData(
    functionFragment: "wormholeRelayer",
    values?: undefined
  ): string;

  decodeFunctionResult(functionFragment: "greetings", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "quoteCrossChainGreeting",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "receiveWormholeMessages",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "sendCrossChainGreeting",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "wormholeRelayer",
    data: BytesLike
  ): Result;

  events: {
    "GreetingReceived(string,uint16,address)": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "GreetingReceived"): EventFragment;
}

export interface GreetingReceivedEventObject {
  greeting: string;
  senderChain: number;
  sender: string;
}
export type GreetingReceivedEvent = TypedEvent<
  [string, number, string],
  GreetingReceivedEventObject
>;

export type GreetingReceivedEventFilter =
  TypedEventFilter<GreetingReceivedEvent>;

export interface HelloWormhole extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: HelloWormholeInterface;

  queryFilter<TEvent extends TypedEvent>(
    event: TypedEventFilter<TEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TEvent>>;

  listeners<TEvent extends TypedEvent>(
    eventFilter?: TypedEventFilter<TEvent>
  ): Array<TypedListener<TEvent>>;
  listeners(eventName?: string): Array<Listener>;
  removeAllListeners<TEvent extends TypedEvent>(
    eventFilter: TypedEventFilter<TEvent>
  ): this;
  removeAllListeners(eventName?: string): this;
  off: OnEvent<this>;
  on: OnEvent<this>;
  once: OnEvent<this>;
  removeListener: OnEvent<this>;

  functions: {
    greetings(arg0: BigNumberish, overrides?: CallOverrides): Promise<[string]>;

    quoteCrossChainGreeting(
      targetChain: BigNumberish,
      overrides?: CallOverrides
    ): Promise<[BigNumber] & { cost: BigNumber }>;

    receiveWormholeMessages(
      payload: BytesLike,
      arg1: BytesLike[],
      sourceAddress: BytesLike,
      sourceChain: BigNumberish,
      arg4: BytesLike,
      overrides?: PayableOverrides & { from?: string }
    ): Promise<ContractTransaction>;

    sendCrossChainGreeting(
      targetChain: BigNumberish,
      targetAddress: string,
      greeting: string,
      overrides?: PayableOverrides & { from?: string }
    ): Promise<ContractTransaction>;

    wormholeRelayer(overrides?: CallOverrides): Promise<[string]>;
  };

  greetings(arg0: BigNumberish, overrides?: CallOverrides): Promise<string>;

  quoteCrossChainGreeting(
    targetChain: BigNumberish,
    overrides?: CallOverrides
  ): Promise<BigNumber>;

  receiveWormholeMessages(
    payload: BytesLike,
    arg1: BytesLike[],
    sourceAddress: BytesLike,
    sourceChain: BigNumberish,
    arg4: BytesLike,
    overrides?: PayableOverrides & { from?: string }
  ): Promise<ContractTransaction>;

  sendCrossChainGreeting(
    targetChain: BigNumberish,
    targetAddress: string,
    greeting: string,
    overrides?: PayableOverrides & { from?: string }
  ): Promise<ContractTransaction>;

  wormholeRelayer(overrides?: CallOverrides): Promise<string>;

  callStatic: {
    greetings(arg0: BigNumberish, overrides?: CallOverrides): Promise<string>;

    quoteCrossChainGreeting(
      targetChain: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    receiveWormholeMessages(
      payload: BytesLike,
      arg1: BytesLike[],
      sourceAddress: BytesLike,
      sourceChain: BigNumberish,
      arg4: BytesLike,
      overrides?: CallOverrides
    ): Promise<void>;

    sendCrossChainGreeting(
      targetChain: BigNumberish,
      targetAddress: string,
      greeting: string,
      overrides?: CallOverrides
    ): Promise<void>;

    wormholeRelayer(overrides?: CallOverrides): Promise<string>;
  };

  filters: {
    "GreetingReceived(string,uint16,address)"(
      greeting?: null,
      senderChain?: null,
      sender?: null
    ): GreetingReceivedEventFilter;
    GreetingReceived(
      greeting?: null,
      senderChain?: null,
      sender?: null
    ): GreetingReceivedEventFilter;
  };

  estimateGas: {
    greetings(
      arg0: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    quoteCrossChainGreeting(
      targetChain: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    receiveWormholeMessages(
      payload: BytesLike,
      arg1: BytesLike[],
      sourceAddress: BytesLike,
      sourceChain: BigNumberish,
      arg4: BytesLike,
      overrides?: PayableOverrides & { from?: string }
    ): Promise<BigNumber>;

    sendCrossChainGreeting(
      targetChain: BigNumberish,
      targetAddress: string,
      greeting: string,
      overrides?: PayableOverrides & { from?: string }
    ): Promise<BigNumber>;

    wormholeRelayer(overrides?: CallOverrides): Promise<BigNumber>;
  };

  populateTransaction: {
    greetings(
      arg0: BigNumberish,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    quoteCrossChainGreeting(
      targetChain: BigNumberish,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    receiveWormholeMessages(
      payload: BytesLike,
      arg1: BytesLike[],
      sourceAddress: BytesLike,
      sourceChain: BigNumberish,
      arg4: BytesLike,
      overrides?: PayableOverrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    sendCrossChainGreeting(
      targetChain: BigNumberish,
      targetAddress: string,
      greeting: string,
      overrides?: PayableOverrides & { from?: string }
    ): Promise<PopulatedTransaction>;

    wormholeRelayer(overrides?: CallOverrides): Promise<PopulatedTransaction>;
  };
}
