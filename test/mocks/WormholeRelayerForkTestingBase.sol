// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../src/interfaces/IWormholeRelayer.sol";
import "../../src/interfaces/IWormhole.sol";
import "../../src/interfaces/ITokenBridge.sol";

import "./MockWormholeRelayer.sol";
import "./helpers/WormholeSimulator.sol";
import "./ERC20Mock.sol";
import "./helpers/DeliveryInstructionDecoder.sol";
import "./helpers/ExecutionParameters.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

abstract contract WormholeRelayerTest is Test {
    uint256 constant DEVNET_GUARDIAN_PK =
        0xcfb12303a19cde580bb4dd771639b0d26bc68353645571a8cff516ab2ee113a0;

    string public constant FUJI_URL =
        "https://api.avax-test.network/ext/bc/C/rpc";
    string public constant CELO_URL =
        "https://alfajores-forno.celo-testnet.org";

    uint16 public constant sourceChain = 6; // fuji testnet
    uint16 public constant targetChain = 14; // celo testnet

    uint public sourceFork;
    uint public targetFork;

    WormholeSimulator public guardianSource;
    WormholeSimulator public guardianTarget;

    // fuji testnet forked contracts
    IWormholeRelayer public relayerSource =
        IWormholeRelayer(0xA3cF45939bD6260bcFe3D66bc73d60f19e49a8BB);
    ITokenBridge public tokenBridgeSource =
        ITokenBridge(0x61E44E506Ca5659E6c0bba9b678586fA2d729756);
    IWormhole public wormholeSource =
        IWormhole(0x7bbcE28e64B3F8b84d876Ab298393c38ad7aac4C);

    // celo testnet forked contracts
    IWormholeRelayer public relayerTarget =
        IWormholeRelayer(0x306B68267Deb7c5DfCDa3619E22E9Ca39C374f84);
    ITokenBridge public tokenBridgeTarget =
        ITokenBridge(0x05ca6037eC51F8b712eD2E6Fa72219FEaE74E153);
    IWormhole public wormholeTarget =
        IWormhole(0x88505117CA88e7dd2eC6EA1E13f0948db2D50D56);

    function setUp() public {
        targetFork = vm.createFork(CELO_URL);
        sourceFork = vm.createSelectFork(FUJI_URL);

        // set up Wormhole using Wormhole existing on FUJI testnet
        guardianSource = new WormholeSimulator(
            address(wormholeSource),
            DEVNET_GUARDIAN_PK
        );
        setUpSource();

        vm.selectFork(targetFork);
        guardianTarget = new WormholeSimulator(
            address(wormholeTarget),
            DEVNET_GUARDIAN_PK
        );
        setUpTarget();

        vm.selectFork(sourceFork);
    }

    function setUpSource() public virtual;

    function setUpTarget() public virtual;

    function performDelivery(uint8 numVaas) public {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length > 0, "no events recorded");

        // find published wormhole messages from log
        Vm.Log[] memory publishedMessages = guardianSource
            .fetchWormholeMessageFromLog(logs, numVaas);

        // simulate signing the Wormhole message
        // NOTE: in the wormhole-sdk, signed Wormhole messages are referred to as signed VAAs
        bytes memory deliveryVaa = guardianSource.fetchSignedMessageFromLogs(
            publishedMessages[0],
            sourceChain
        );

        bytes[] memory additionalVaas = new bytes[](numVaas - 1);
        for (uint8 i = 1; i < numVaas; i++) {
            additionalVaas[i - 1] = guardianSource.fetchSignedMessageFromLogs(
                publishedMessages[i],
                sourceChain
            );
        }

        vm.selectFork(targetFork);

        IWormhole.VM memory deliveryParsed = wormholeTarget.parseVM(
            deliveryVaa
        );
        DeliveryInstruction memory ix = decodeDeliveryInstruction(
            deliveryParsed.payload
        );
        EvmExecutionInfoV1 memory execInfo = decodeEvmExecutionInfoV1(
            ix.encodedExecutionInfo
        );

        relayerTarget.deliver{
            value: ix.requestedReceiverValue +
                ix.extraReceiverValue +
                execInfo.targetChainRefundPerGasUnused *
                execInfo.gasLimit
        }(additionalVaas, deliveryVaa, payable(address(this)), new bytes(0));

        vm.selectFork(sourceFork);
    }

    receive() external payable {}
}
