// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title AgentStaking
 * @notice Economic security layer for the Agent Registry.
 *         Agents stake ETH to earn trust. Bad agents get slashed.
 *         Slashed funds: 50% to whistleblower, 50% burned forever.
 *
 * @dev Immutable. No owner extraction of slashed funds.
 *      Burn address: 0x000000000000000000000000000000000000dEaD
 */

contract AgentStaking {
    // ═══════════════════════════════════════════
    //  Constants
    // ═══════════════════════════════════════════

    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    uint256 public constant COOLDOWN_PERIOD = 7 days;

    // Agent type → required stake amount (in wei)
    // Type 0 = informational ($50), Type 1 = trading ($200), Type 2 = custodial ($500)
    mapping(uint8 => uint256) public requiredStake;

    // ═══════════════════════════════════════════
    //  Errors
    // ═══════════════════════════════════════════

    error Unauthorized();
    error InvalidAgentId();
    error AlreadyStaked();
    error NotStaked();
    error InsufficientStake();
    error CooldownActive(uint256 unlockTime);
    error NoCooldown();
    error DisputeActive();

    // ═══════════════════════════════════════════
    //  Events
    // ═══════════════════════════════════════════

    event Staked(uint256 indexed agentId, address indexed staker, uint256 amount, uint8 agentType);
    event WithdrawRequested(uint256 indexed agentId, uint256 unlockTime);
    event Withdrawn(uint256 indexed agentId, address indexed staker, uint256 amount);
    event Slashed(
        uint256 indexed agentId,
        uint256 totalAmount,
        uint256 whistleblowerReward,
        uint256 burned,
        address indexed whistleblower
    );
    event Graduated(uint256 indexed agentId, uint256 amountReturned);

    // ═══════════════════════════════════════════
    //  Structs
    // ═══════════════════════════════════════════

    struct StakeInfo {
        uint256 amount;          // Amount staked (wei)
        uint8 agentType;         // Agent type (0=info, 1=trading, 2=custodial)
        uint256 stakedAt;        // Timestamp when staked
        uint256 cooldownUnlock;  // 0 = no cooldown active
        address staker;          // Who staked
        bool active;             // Is stake currently active
    }

    // ═══════════════════════════════════════════
    //  State
    // ═══════════════════════════════════════════

    address public owner;

    /// @notice Agent ID → Stake info
    mapping(uint256 => StakeInfo) public stakes;

    /// @notice Authorized slashers (can be attestors from AgentRegistry, oracles, etc.)
    mapping(address => bool) public slashers;

    /// @notice Total ETH burned through slashing (public audit trail)
    uint256 public totalBurned;

    /// @notice Total ETH paid to whistleblowers
    uint256 public totalWhistleblowerPaid;

    // ═══════════════════════════════════════════
    //  Modifiers
    // ═══════════════════════════════════════════

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlySlasher() {
        if (!slashers[msg.sender]) revert Unauthorized();
        _;
    }

    modifier noActiveCooldown(uint256 agentId) {
        if (stakes[agentId].cooldownUnlock > block.timestamp) {
            revert CooldownActive(stakes[agentId].cooldownUnlock);
        }
        _;
    }

    // ═══════════════════════════════════════════
    //  Constructor
    // ═══════════════════════════════════════════

    constructor() {
        owner = msg.sender;

        // Initialize required stakes
        // $50  @ $2000/ETH = 0.025 ether (info)
        // $200 @ $2000/ETH = 0.1 ether (trading)
        // $500 @ $2000/ETH = 0.25 ether (custodial)
        // These can be updated by owner if ETH price changes dramatically
        requiredStake[0] = 0.025 ether;   // Informational
        requiredStake[1] = 0.1 ether;     // Trading
        requiredStake[2] = 0.25 ether;    // Custodial
    }

    // ═══════════════════════════════════════════
    //  Staking
    // ═══════════════════════════════════════════

    /// @notice Stake ETH for an agent
    /// @param agentId Agent's ID in AgentRegistry
    /// @param agentType 0=info, 1=trading, 2=custodial
    function stake(uint256 agentId, uint8 agentType) external payable {
        if (agentId == 0) revert InvalidAgentId();
        if (stakes[agentId].active) revert AlreadyStaked();
        if (msg.value < requiredStake[agentType]) revert InsufficientStake();

        stakes[agentId] = StakeInfo({
            amount: msg.value,
            agentType: agentType,
            stakedAt: block.timestamp,
            cooldownUnlock: 0,
            staker: msg.sender,
            active: true
        });

        // Refund excess if sent more than required
        uint256 excess = msg.value - requiredStake[agentType];
        if (excess > 0) {
            (bool refunded,) = payable(msg.sender).call{value: excess}("");
            require(refunded, "Refund failed");
            stakes[agentId].amount = requiredStake[agentType];
        }

        emit Staked(agentId, msg.sender, requiredStake[agentType], agentType);
    }

    // ═══════════════════════════════════════════
    //  Withdrawal (with cooldown)
    // ═══════════════════════════════════════════

    /// @notice Request withdrawal. Starts 7-day cooldown.
    function requestWithdrawal(uint256 agentId) external {
        StakeInfo storage s = stakes[agentId];
        if (!s.active) revert NotStaked();
        if (s.staker != msg.sender) revert Unauthorized();
        if (s.cooldownUnlock > block.timestamp) revert CooldownActive(s.cooldownUnlock);

        s.cooldownUnlock = block.timestamp + COOLDOWN_PERIOD;
        emit WithdrawRequested(agentId, s.cooldownUnlock);
    }

    /// @notice Complete withdrawal after cooldown
    function withdraw(uint256 agentId) external noActiveCooldown(agentId) {
        StakeInfo storage s = stakes[agentId];
        if (!s.active) revert NotStaked();
        if (s.staker != msg.sender) revert Unauthorized();
        if (s.cooldownUnlock == 0) revert NoCooldown();

        uint256 amount = s.amount;
        s.active = false;
        s.amount = 0;
        s.cooldownUnlock = 0;

        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "Withdrawal failed");

        emit Withdrawn(agentId, msg.sender, amount);
    }

    // ═══════════════════════════════════════════
    //  Graduation (auto-return)
    // ═══════════════════════════════════════════

    /// @notice Graduate an agent — return stake without cooldown.
    ///         Called by slasher/attestor when agent meets graduation criteria.
    function graduate(uint256 agentId) external onlySlasher {
        StakeInfo storage s = stakes[agentId];
        if (!s.active) revert NotStaked();

        uint256 amount = s.amount;
        address staker = s.staker;
        s.active = false;
        s.amount = 0;

        (bool success,) = payable(staker).call{value: amount}("");
        require(success, "Graduation refund failed");

        emit Graduated(agentId, amount);
    }

    // ═══════════════════════════════════════════
    //  Slashing (only authorized slashers)
    // ═══════════════════════════════════════════

    /// @notice Slash an agent's stake. 50% to whistleblower, 50% burned.
    /// @param agentId Agent to slash
    /// @param whistleblower Address receiving the reward
    function slash(uint256 agentId, address whistleblower) external onlySlasher {
        StakeInfo storage s = stakes[agentId];
        if (!s.active) revert NotStaked();

        uint256 total = s.amount;
        uint256 whistleblowerReward = total / 2;
        uint256 burnAmount = total - whistleblowerReward; // The rest (handles odd wei)

        s.active = false;
        s.amount = 0;
        totalBurned += burnAmount;
        totalWhistleblowerPaid += whistleblowerReward;

        // Send reward to whistleblower
        (bool rewardSent,) = payable(whistleblower).call{value: whistleblowerReward}("");
        require(rewardSent, "Whistleblower reward failed");

        // Burn the rest
        (bool burned,) = payable(BURN_ADDRESS).call{value: burnAmount}("");
        require(burned, "Burn failed");

        emit Slashed(agentId, total, whistleblowerReward, burnAmount, whistleblower);
    }

    // ═══════════════════════════════════════════
    //  Admin
    // ═══════════════════════════════════════════

    /// @notice Update required stake for an agent type (ETH price adjustment)
    function updateRequiredStake(uint8 agentType, uint256 newAmount) external onlyOwner {
        requiredStake[agentType] = newAmount;
    }

    /// @notice Authorize a slasher
    function addSlasher(address slasher) external onlyOwner {
        slashers[slasher] = true;
    }

    /// @notice Revoke slasher authorization
    function removeSlasher(address slasher) external onlyOwner {
        slashers[slasher] = false;
    }

    /// @notice Transfer ownership
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    // ═══════════════════════════════════════════
    //  Queries
    // ═══════════════════════════════════════════

    /// @notice Check if an agent has an active stake
    function isStaked(uint256 agentId) external view returns (bool) {
        return stakes[agentId].active;
    }

    /// @notice Get stake amount for an agent
    function getStake(uint256 agentId) external view returns (uint256) {
        return stakes[agentId].amount;
    }

    /// @notice Get required stake in USD terms for display
    function getRequiredStakeUSD(uint8 agentType) external pure returns (uint256) {
        if (agentType == 0) return 50;
        if (agentType == 1) return 200;
        if (agentType == 2) return 500;
        return 0;
    }
}
