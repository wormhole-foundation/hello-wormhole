// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/HelloWormhole.sol";

contract HelloWormholeScript is Script {
    event Deployed(address addr);

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address relayer = vm.envAddress("WORMHOLE_RELAYER");
        vm.startBroadcast(deployerPrivateKey);

        HelloWormhole hello = new HelloWormhole(relayer);

        emit Deployed(address(hello));

        vm.stopBroadcast();
    }
}
