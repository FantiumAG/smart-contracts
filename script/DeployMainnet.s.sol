// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { Script } from "forge-std/Script.sol";
import { Core } from "@openzeppelin/foundry-upgrades/internal/Core.sol";
import { Options } from "@openzeppelin/foundry-upgrades/Options.sol";

contract DeployMainnetV5 is Script {
    function run() public {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        Options memory opts;
        Core.prepareUpgrade("FANtiumNFTV6.sol", opts);
        vm.stopBroadcast();
    }
}
