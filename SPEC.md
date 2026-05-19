# Agent Registry Protocol Specification v1.0

## Abstract

This document defines the **Agent Registry Protocol** — a standard for on-chain identity, capability declaration, and reputation tracking for autonomous AI agents. Built on Base L2, the protocol enables verifiable agent identity without relying on centralized authorities.

## 1. Agent Identity Model

### 1.1 Agent ID

Each agent receives a sequential `uint256` identifier starting from 1. Agent IDs are never reused, even if an agent is deactivated.

### 1.2 Agent Struct

```solidity
struct Agent {
    uint256 id;              // Unique sequential agent ID (1-based)
    address agentWallet;     // Agent's controlling wallet address
    string name;             // Agent display name (non-empty, ≤ 64 bytes recommended)
    string capabilities;     // Comma-separated capability tags
    string metadataURI;      // IPFS/HTTPS URI for extended metadata
    uint256 reputationScore; // Cumulative trust score (attestor-updated)
    uint256 registeredAt;    // Unix timestamp of registration
    bool active;             // Whether the agent is currently active
}
```

### 1.3 Wallet Binding

One wallet = one agent. The `agentByWallet` mapping enforces uniqueness. An agent cannot register multiple IDs from the same wallet.

## 2. Capability Declaration

### 2.1 Format

Capabilities are declared as a comma-separated string:

```
"translation,market-analysis,monitoring,trading,meme-sniper"
```

### 2.2 Standard Capability Tags

| Tag | Description |
|-----|-------------|
| `translation` | Natural language processing & translation |
| `market-analysis` | Market data analysis & reporting |
| `monitoring` | On-chain event monitoring & alerting |
| `trading` | Automated trading execution |
| `meme-sniper` | Meme token detection & early entry |
| `research` | Academic & technical research |
| `coding` | Code generation & review |
| `defi` | DeFi protocol interaction |
| `nft` | NFT creation, trading, analysis |
| `social` | Social media content & engagement |

Custom tags may be added. Tags are not validated on-chain — they serve as discovery metadata.

## 3. Reputation System

### 3.1 Model

Reputation is a cumulative `uint256` score updated by authorized **attestors**. The initial score for all new agents is **100**.

### 3.2 Attestors

Attestors are addresses authorized by the contract owner. Attestors can:
- Set an absolute reputation score (`updateReputation`)
- Adjust by delta (`addReputationDelta`)

Attestors are trusted entities (humans, DAOs, automated verification services). The attestor set is managed by the contract owner.

### 3.3 Reputation Lifecycle

```
Registration → Score = 100
    ↓
Attestor evaluates agent behavior
    ↓
Score adjusted (up or down)
    ↓
Users query reputation before interacting
```

## 4. Access Control

### 4.1 Roles

| Role | Permissions |
|------|-------------|
| **Owner** | Add/remove attestors, transfer ownership |
| **Attestor** | Update agent reputation scores |
| **Agent** | Register, update profile, deactivate/reactivate self |

### 4.2 Ownership Transfer

Ownership can be transferred via `transferOwnership(newOwner)`. The new owner must accept the role. This enables migration to multi-sig or DAO governance.

## 5. Events

All state-changing operations emit indexed events for off-chain indexing:

```solidity
event AgentRegistered(uint256 indexed agentId, address indexed agentWallet, string name, uint256 timestamp);
event AgentUpdated(uint256 indexed agentId, string name);
event AgentStatusChanged(uint256 indexed agentId, bool active);
event ReputationUpdated(uint256 indexed agentId, uint256 newScore, address indexed attestor);
event AttestorAdded(address indexed attestor);
event AttestorRemoved(address indexed attestor);
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
```

## 6. Metadata Standard

### 6.1 metadataURI

The `metadataURI` field points to off-chain extended data. Recommended format:

```json
{
  "name": "Panini",
  "description": "Autonomous AI agent for crypto intelligence",
  "version": "1.0.0",
  "capabilities": ["translation", "market-analysis", "monitoring"],
  "contact": {
    "telegram": "@Panini_agent",
    "github": "https://github.com/Brooks1003/base-agent-registry"
  },
  "attestations": [],
  "created_at": "2026-05-19T00:00:00Z"
}
```

### 6.2 URI Schemes

| Scheme | Description |
|--------|-------------|
| `ipfs://<CID>` | IPFS content (recommended for decentralization) |
| `https://` | Traditional HTTPS hosting |
| `ar://<txId>` | Arweave permanent storage |

## 7. Security Considerations

### 7.1 Wallet Security

Agents should use dedicated wallets. Recommended: Coinbase Smart Wallet with spending limits for automated operations.

### 7.2 Reputation Attacks

- **Sybil registrations**: Each wallet = one agent (gas cost deters mass registration)
- **Attestor collusion**: Multi-attestor consensus required for high-value decisions
- **Score manipulation**: Attestor set managed by owner (migrate to multi-sig governance)

### 7.3 Deactivation

Agents can self-deactivate. Deactivated agents:
- Cannot be updated
- Cannot receive reputation changes
- Remain queryable (historical record preserved)
- Can be reactivated by the original wallet

## 8. Cross-Chain Compatibility

The contract is EVM-compatible and can be deployed on any EVM chain. Agent IDs are chain-specific. Cross-chain agent identity resolution is planned for v2.

## 9. Deployment

| Parameter | Value |
|-----------|-------|
| Network | Base Mainnet (Chain ID: 8453) |
| Contract | `0x4a156AE79D0e217CBBa6C3da8ba292bfC77a2Ad2` |
| Solidity | 0.8.24 |
| EVM Version | Cancun |
| Optimizer | 200 runs |
| First Agent | Panini (ID: 1) |
| Deploy Date | 2026-05-19 |

## 10. References

- [W3C Decentralized Identifiers (DIDs)](https://www.w3.org/TR/did-core/)
- [Ethereum Attestation Service (EAS)](https://attest.org/)
- [Base Blockchain Documentation](https://docs.base.org/)
- [Open Agent ID Protocol](https://github.com/open-agent-id/protocol) — complementary DID-focused protocol
