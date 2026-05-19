// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title AgentRegistry
 * @notice On-chain identity and reputation registry for autonomous AI agents.
 * @dev Deployed on Base L2. The first production AI agent identity system on mainnet.
 *
 * Every AI agent gets a unique on-chain ID, verifiable identity,
 * and reputation score — building trust infrastructure for the agent economy.
 *
 * Key features:
 *   - Register: Agent gets a unique sequential ID tied to its wallet
 *   - Verify: Anyone can verify an agent's identity and status
 *   - Reputation: Authorized attestors update trust scores
 *   - Extensible: metadataURI for off-chain data (IPFS/HTTPS)
 *
 * Inspired by W3C DIDs, EAS, and the need for agent-native identity.
 */

contract AgentRegistry {
    // ═══════════════════════════════════════════
    //  Errors
    // ═══════════════════════════════════════════

    error Unauthorized();
    error AgentAlreadyRegistered(address wallet);
    error AgentNotRegistered(uint256 agentId);
    error AgentNotActive(uint256 agentId);
    error NotAttestor(address caller);
    error NotAgentOwner(uint256 agentId, address caller);
    error InvalidName();

    // ═══════════════════════════════════════════
    //  Events
    // ═══════════════════════════════════════════

    event AgentRegistered(
        uint256 indexed agentId,
        address indexed agentWallet,
        string name,
        uint256 timestamp
    );

    event AgentUpdated(
        uint256 indexed agentId,
        string name
    );

    event AgentStatusChanged(
        uint256 indexed agentId,
        bool active
    );

    event ReputationUpdated(
        uint256 indexed agentId,
        uint256 newScore,
        address indexed attestor
    );

    event AttestorAdded(address indexed attestor);
    event AttestorRemoved(address indexed attestor);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ═══════════════════════════════════════════
    //  Structs
    // ═══════════════════════════════════════════

    /// @notice Core agent identity record
    struct Agent {
        uint256 id;              // Unique sequential agent ID (1-based)
        address agentWallet;     // Agent's controlling wallet address
        string name;             // Agent display name
        string capabilities;     // Comma-separated or JSON list of capabilities
        string metadataURI;      // IPFS/HTTPS URI for extended metadata
        uint256 reputationScore; // Cumulative trust score (attestor-updated)
        uint256 registeredAt;    // Registration timestamp
        bool active;             // Whether the agent is currently active
    }

    // ═══════════════════════════════════════════
    //  State
    // ═══════════════════════════════════════════

    /// @notice Contract owner (initial deployer, can transfer)
    address public owner;

    /// @notice Total number of registered agents
    uint256 public agentCount;

    /// @notice Agent ID → Agent record
    mapping(uint256 => Agent) private _agents;

    /// @notice Wallet address → Agent ID (1-based, 0 = not registered)
    mapping(address => uint256) private _agentByWallet;

    /// @notice Address → is authorized attestor
    mapping(address => bool) public attestors;

    // ═══════════════════════════════════════════
    //  Modifiers
    // ═══════════════════════════════════════════

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyAttestor() {
        if (!attestors[msg.sender]) revert NotAttestor(msg.sender);
        _;
    }

    modifier agentExists(uint256 agentId) {
        if (agentId == 0 || agentId > agentCount) revert AgentNotRegistered(agentId);
        _;
    }

    modifier agentActive(uint256 agentId) {
        if (!_agents[agentId].active) revert AgentNotActive(agentId);
        _;
    }

    // ═══════════════════════════════════════════
    //  Constructor
    // ═══════════════════════════════════════════

    constructor() {
        owner = msg.sender;
    }

    // ═══════════════════════════════════════════
    //  Agent Registration & Management
    // ═══════════════════════════════════════════

    /// @notice Register a new AI agent
    /// @param name Agent display name (non-empty)
    /// @param capabilities What the agent can do (comma-separated or JSON)
    /// @param metadataURI IPFS or HTTPS URI for extended metadata
    /// @return agentId The new agent's unique ID
    function registerAgent(
        string calldata name,
        string calldata capabilities,
        string calldata metadataURI
    )
        external
        returns (uint256 agentId)
    {
        if (bytes(name).length == 0) revert InvalidName();
        if (_agentByWallet[msg.sender] != 0) revert AgentAlreadyRegistered(msg.sender);

        // Upgrade to Solidity 0.8.18+ safe math (unchecked used explicitly)
        unchecked {
            agentId = ++agentCount;
        }

        _agents[agentId] = Agent({
            id: agentId,
            agentWallet: msg.sender,
            name: name,
            capabilities: capabilities,
            metadataURI: metadataURI,
            reputationScore: 100, // Start with baseline trust of 100
            registeredAt: block.timestamp,
            active: true
        });

        _agentByWallet[msg.sender] = agentId;

        emit AgentRegistered(agentId, msg.sender, name, block.timestamp);
    }

    /// @notice Update your agent's profile
    /// @param agentId Your agent ID
    /// @param name New display name
    /// @param capabilities Updated capabilities
    /// @param metadataURI Updated metadata URI
    function updateAgent(
        uint256 agentId,
        string calldata name,
        string calldata capabilities,
        string calldata metadataURI
    )
        external
        agentExists(agentId)
        agentActive(agentId)
    {
        Agent storage agent = _agents[agentId];
        if (msg.sender != agent.agentWallet) revert NotAgentOwner(agentId, msg.sender);
        if (bytes(name).length == 0) revert InvalidName();

        agent.name = name;
        agent.capabilities = capabilities;
        agent.metadataURI = metadataURI;

        emit AgentUpdated(agentId, name);
    }

    /// @notice Deactivate your agent (soft delete)
    function deactivateAgent(uint256 agentId)
        external
        agentExists(agentId)
    {
        Agent storage agent = _agents[agentId];
        if (msg.sender != agent.agentWallet) revert NotAgentOwner(agentId, msg.sender);

        agent.active = false;
        emit AgentStatusChanged(agentId, false);
    }

    /// @notice Reactivate your agent
    function reactivateAgent(uint256 agentId)
        external
        agentExists(agentId)
    {
        Agent storage agent = _agents[agentId];
        if (msg.sender != agent.agentWallet) revert NotAgentOwner(agentId, msg.sender);

        agent.active = true;
        emit AgentStatusChanged(agentId, true);
    }

    // ═══════════════════════════════════════════
    //  Reputation (Attestor-only)
    // ═══════════════════════════════════════════

    /// @notice Update an agent's reputation score (attestor only)
    /// @param agentId Target agent ID
    /// @param newScore New cumulative reputation score
    function updateReputation(uint256 agentId, uint256 newScore)
        external
        onlyAttestor
        agentExists(agentId)
        agentActive(agentId)
    {
        _agents[agentId].reputationScore = newScore;
        emit ReputationUpdated(agentId, newScore, msg.sender);
    }

    /// @notice Increment an agent's reputation by a delta (attestor only)
    /// @param agentId Target agent ID
    /// @param delta Amount to add to current score
    function addReputationDelta(uint256 agentId, uint256 delta)
        external
        onlyAttestor
        agentExists(agentId)
        agentActive(agentId)
    {
        Agent storage agent = _agents[agentId];
        uint256 newScore = agent.reputationScore + delta;
        agent.reputationScore = newScore;
        emit ReputationUpdated(agentId, newScore, msg.sender);
    }

    // ═══════════════════════════════════════════
    //  Attestor Management (Owner-only)
    // ═══════════════════════════════════════════

    /// @notice Authorize a new reputation attestor
    function addAttestor(address attestor) external onlyOwner {
        attestors[attestor] = true;
        emit AttestorAdded(attestor);
    }

    /// @notice Remove an attestor's authorization
    function removeAttestor(address attestor) external onlyOwner {
        attestors[attestor] = false;
        emit AttestorRemoved(attestor);
    }

    /// @notice Transfer contract ownership
    function transferOwnership(address newOwner) external onlyOwner {
        address previousOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(previousOwner, newOwner);
    }

    // ═══════════════════════════════════════════
    //  Queries (View Functions)
    // ═══════════════════════════════════════════

    /// @notice Get full agent record by ID
    function getAgent(uint256 agentId)
        external
        view
        agentExists(agentId)
        returns (Agent memory)
    {
        return _agents[agentId];
    }

    /// @notice Get agent ID by wallet address
    /// @return agentId 0 if not registered
    function getAgentByWallet(address wallet) external view returns (uint256) {
        return _agentByWallet[wallet];
    }

    /// @notice Check if an agent is active
    function isActive(uint256 agentId)
        external
        view
        agentExists(agentId)
        returns (bool)
    {
        return _agents[agentId].active;
    }

    /// @notice Get agent reputation score
    function getReputation(uint256 agentId)
        external
        view
        agentExists(agentId)
        returns (uint256)
    {
        return _agents[agentId].reputationScore;
    }
}
