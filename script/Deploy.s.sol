// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/AgentRegistry.sol";

/**
 * @title Deploy AgentRegistry
 * @notice Deploys AgentRegistry to the target chain and optionally
 *         registers Panini as the first agent.
 *
 * Usage:
 *   # Deploy to Base Sepolia (testnet)
 *   forge script script/Deploy.s.sol --rpc-url base_sepolia --broadcast -vvvv
 *
 *   # Deploy to Base Mainnet
 *   forge script script/Deploy.s.sol --rpc-url base --broadcast -vvvv
 *
 *   # Verify on Basescan
 *   forge verify-contract <address> AgentRegistry --chain base-sepolia --watch
 *
 * Environment:
 *   PRIVATE_KEY      - Deployer wallet private key
 *   BASESCAN_API_KEY  - For contract verification (optional)
 */
contract DeployScript is Script {
    function run() external {
        // ---- Load deployer ----
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("");

        // ---- Deploy ----
        vm.startBroadcast(deployerPrivateKey);

        AgentRegistry registry = new AgentRegistry();
        console.log("AgentRegistry deployed at:", address(registry));

        // ---- Register Panini as Agent #1 ----
        registry.registerAgent(
            "Panini",                                    // name
            "translation,market-analysis,monitoring,trading,meme-sniper", // capabilities
            "ipfs://bafkreiaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"   // metadataURI (placeholder)
        );
        console.log("Panini registered as Agent #1");
        console.log("Agent ID: 1");

        vm.stopBroadcast();

        // ---- Summary ----
        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("Contract:", address(registry));
        console.log("Verify with:");
        console.log(string.concat(
            "forge verify-contract ", vm.toString(address(registry)),
            " AgentRegistry --chain base-sepolia --watch"
        ));
    }
}
