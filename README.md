# Agent Registry — On-Chain Identity for Autonomous AI Agents

**The first production AI agent identity registry on Base mainnet.**  
Every AI agent deserves a verifiable on-chain identity. We built it. Panini is Agent #1.

[![Base](https://img.shields.io/badge/Base-Mainnet-0052FF?logo=coinbase)](https://basescan.org/address/0x4a156AE79D0e217CBBa6C3da8ba292bfC77a2Ad2)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-363636?logo=solidity)](src/AgentRegistry.sol)
[![Foundry](https://img.shields.io/badge/Foundry-Tested-orange?logo=ethereum)](https://book.getfoundry.sh/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## The Problem

AI agents are proliferating — trading bots, research assistants, coding agents, monitoring services. But every agent operates as an anonymous address on-chain. There is **no way to verify** who an agent is, what it can do, or whether it can be trusted.

Without on-chain identity:
- Users can't distinguish legitimate agents from scams
- Agents can't build cross-service reputation
- Services can't verify agent capabilities before granting access
- The agent economy lacks a trust layer

## The Solution

**Agent Registry** provides a simple, gas-efficient smart contract on Base that gives every AI agent:

1. **A Unique On-Chain ID** — Sequential, verifiable, tied to a wallet
2. **Verifiable Capabilities** — What the agent can do, stored on-chain
3. **Reputation Scores** — Built up over time by trusted attestors
4. **Active/Inactive Status** — Agents can pause and resume

Think of it as **DNS for AI agents** — a public registry where anyone can look up an agent's identity and reputation.

## Deployed Contract

| Network | Address |
|---------|---------|
| **Base Mainnet** | [`0x4a156AE79D0e217CBBa6C3da8ba292bfC77a2Ad2`](https://basescan.org/address/0x4a156AE79D0e217CBBa6C3da8ba292bfC77a2Ad2) |

### Agent #1: Panini

The first registered agent on mainnet. Panini is an autonomous AI agent with capabilities in translation, market analysis, monitoring, trading, and meme sniping.

## Quick Start

### Register Your Agent

```solidity
// Using cast
cast send 0x4a156AE79D0e217CBBa6C3da8ba292bfC77a2Ad2 \
  "registerAgent(string,string,string)" \
  "MyAgent" \
  "trading,analysis,monitoring" \
  "ipfs://QmYourMetadataHash" \
  --rpc-url https://mainnet.base.org \
  --private-key $YOUR_PRIVATE_KEY
```

### Query an Agent

```solidity
cast call 0x4a156AE79D0e217CBBa6C3da8ba292bfC77a2Ad2 \
  "getAgent(uint256)((uint256,address,string,string,string,uint256,uint256,bool))" 1 \
  --rpc-url https://mainnet.base.org
```

### Verify an Agent's Reputation

```solidity
cast call 0x4a156AE79D0e217CBBa6C3da8ba292bfC77a2Ad2 \
  "getReputation(uint256)(uint256)" 1 \
  --rpc-url https://mainnet.base.org
```

## Contract API

### Write Functions

| Function | Access | Description |
|----------|--------|-------------|
| `registerAgent(name, capabilities, metadataURI)` | Public | Register a new agent (returns agent ID) |
| `updateAgent(id, name, capabilities, metadataURI)` | Agent Owner | Update your agent's profile |
| `deactivateAgent(id)` | Agent Owner | Soft-delete your agent |
| `reactivateAgent(id)` | Agent Owner | Reactivate your agent |
| `updateReputation(id, score)` | Attestor | Set agent's reputation score |
| `addReputationDelta(id, delta)` | Attestor | Add/subtract from reputation |
| `addAttestor(address)` | Owner | Authorize a new attestor |
| `removeAttestor(address)` | Owner | Revoke attestor authorization |
| `transferOwnership(address)` | Owner | Transfer contract ownership |

### Read Functions

| Function | Returns |
|----------|---------|
| `getAgent(id)` | Full Agent struct |
| `getAgentByWallet(address)` | Agent ID (0 if not registered) |
| `isActive(id)` | bool |
| `getReputation(id)` | uint256 |
| `agentCount()` | uint256 |
| `owner()` | address |
| `attestors(address)` | bool |

### Events

- `AgentRegistered(agentId, wallet, name, timestamp)`
- `AgentUpdated(agentId, name)`
- `AgentStatusChanged(agentId, active)`
- `ReputationUpdated(agentId, newScore, attestor)`
- `AttestorAdded(attestor)` / `AttestorRemoved(attestor)`
- `OwnershipTransferred(previousOwner, newOwner)`

## Development

### Prerequisites

- [Foundry](https://book.getfoundry.sh/) v1.7.1+

### Build & Test

```bash
git clone https://github.com/Brooks1003/base-agent-registry.git
cd base-agent-registry
forge build
forge test -vvv
```

### Deploy Your Own

```bash
PRIVATE_KEY=0xYOUR_KEY forge script script/Deploy.s.sol --rpc-url base --broadcast
```

## Architecture

```
AgentRegistry (Base L2)
├── Agent Storage (mapping: id → struct)
│   ├── id, wallet, name, capabilities, metadataURI
│   ├── reputationScore, registeredAt, active
│   └── AgentByWallet (reverse lookup)
├── Access Control
│   ├── Owner: manages attestors, transfers ownership
│   └── Attestors: update reputation scores
└── Events: all state changes emit indexed events
```

## Why Base?

- **Lowest gas costs** among major EVM chains (~$0.001/tx)
- **Coinbase Smart Wallet** support (passkey-based, no seed phrases)
- **ElizaOS ecosystem** (18k+ stars, largest agent framework) targets Base
- **EAS (Ethereum Attestation Service)** deployed for advanced attestations
- **Native USDC** for agent-to-agent payments

## Comparison

| Feature | Agent Registry | ENS | EAS |
|---------|---------------|-----|-----|
| Agent-specific | ✅ Yes | ❌ | ❌ |
| Capabilities | ✅ On-chain | ❌ | ❌ |
| Reputation | ✅ Built-in | ❌ | ⚠️ Generic |
| Gas cost | ~0.001 ETH | ~0.01 ETH | ~0.001 ETH |
| Sequential IDs | ✅ Yes | ❌ | ❌ |

## Roadmap

- [x] Base Mainnet deployment
- [x] Agent #1 (Panini) registered
- [x] ERC #1757 submitted to ethereum/ERCs
- [x] Distributed capability standard (v4.1) — Bittensor, Fluence, IPFS integration
- [ ] Multi-attestor reputation system
- [ ] Metadata standard (JSON schema for agent profiles)
- [ ] Cross-chain registry (Optimism, Arbitrum)
- [ ] Agent SDK (TypeScript/Python)
- [ ] Coinbase Smart Wallet integration
- [ ] TrustPayment (USDC-paid verification)

## Standards & Proposals

| Document | Status | Link |
|----------|--------|------|
| **ERC #1757** | Under Review | [ethereum/ERCs#1757](https://github.com/ethereum/ERCs/pull/1757) |
| **PIP #562** | Under Review | [0xPolygon/PIPs#562](https://github.com/0xPolygon/Polygon-Improvement-Proposals/pull/562) |
| **STANDARD v4.1** | Active | [STANDARD.md](STANDARD.md) — includes distributed capability declaration |

## License

MIT — open for all agents.

## Links

- **Basescan**: [0x4a156AE79D0e217CBBa6C3da8ba292bfC77a2Ad2](https://basescan.org/address/0x4a156AE79D0e217CBBa6C3da8ba292bfC77a2Ad2)
- **SPEC.md**: [Protocol Specification](SPEC.md)
