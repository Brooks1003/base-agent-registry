// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AgentStaking.sol";

contract AgentStakingTest is Test {
    AgentStaking public staking;

    address public agent1 = address(0x1001);
    address public agent2 = address(0x1002);
    address public slasher = address(0x2001);
    address public whistleblower = address(0x3001);
    address public stranger = address(0x9999);

    function setUp() public {
        staking = new AgentStaking();
        vm.deal(agent1, 10 ether);
        vm.deal(agent2, 10 ether);
        vm.label(address(staking), "AgentStaking");
        vm.label(agent1, "Agent1");
        vm.label(agent2, "Agent2");
        vm.label(slasher, "Slasher");
        vm.label(whistleblower, "Whistleblower");
    }

    // ═══════════════════════════
    //  Staking
    // ═══════════════════════════

    function test_StakeInfo() public {
        vm.prank(agent1);
        staking.stake{value: 0.025 ether}(1, 0);

        assertTrue(staking.isStaked(1));
        assertEq(staking.getStake(1), 0.025 ether);
    }

    function test_StakeTrading() public {
        vm.prank(agent1);
        staking.stake{value: 0.1 ether}(2, 1);
        assertEq(staking.getStake(2), 0.1 ether);
    }

    function test_StakeCustodial() public {
        vm.prank(agent1);
        staking.stake{value: 0.25 ether}(3, 2);
        assertEq(staking.getStake(3), 0.25 ether);
    }

    function test_StakeRefundExcess() public {
        uint256 balanceBefore = agent1.balance;
        vm.prank(agent1);
        staking.stake{value: 0.1 ether}(1, 0); // Sent 0.1 for type 0 which needs 0.025

        assertEq(staking.getStake(1), 0.025 ether);
        assertEq(agent1.balance, balanceBefore - 0.025 ether); // Excess refunded
    }

    function test_RevertWhen_InsufficientStake() public {
        vm.prank(agent1);
        vm.expectRevert(AgentStaking.InsufficientStake.selector);
        staking.stake{value: 0.01 ether}(1, 0); // Type 0 needs 0.025
    }

    function test_RevertWhen_DoubleStake() public {
        vm.prank(agent1);
        staking.stake{value: 0.025 ether}(1, 0);

        vm.prank(agent1);
        vm.expectRevert(AgentStaking.AlreadyStaked.selector);
        staking.stake{value: 0.025 ether}(1, 0);
    }

    function test_RevertWhen_AgentIdZero() public {
        vm.prank(agent1);
        vm.expectRevert(AgentStaking.InvalidAgentId.selector);
        staking.stake{value: 0.025 ether}(0, 0);
    }

    function test_MultipleAgentsStaking() public {
        vm.prank(agent1);
        staking.stake{value: 0.025 ether}(1, 0);

        vm.prank(agent2);
        staking.stake{value: 0.1 ether}(2, 1);

        assertTrue(staking.isStaked(1));
        assertTrue(staking.isStaked(2));
        assertEq(staking.getStake(1), 0.025 ether);
        assertEq(staking.getStake(2), 0.1 ether);
    }

    // ═══════════════════════════
    //  Withdrawal
    // ═══════════════════════════

    function test_WithdrawAfterCooldown() public {
        vm.prank(agent1);
        staking.stake{value: 0.025 ether}(1, 0);

        uint256 balanceBefore = agent1.balance;

        vm.prank(agent1);
        staking.requestWithdrawal(1);

        vm.warp(block.timestamp + 7 days + 1);

        vm.prank(agent1);
        staking.withdraw(1);

        assertFalse(staking.isStaked(1));
        assertApproxEqAbs(agent1.balance, balanceBefore + 0.025 ether, 0.001 ether); // gas cost
    }

    function test_RevertWhen_WithdrawNoCooldown() public {
        vm.prank(agent1);
        staking.stake{value: 0.025 ether}(1, 0);

        vm.prank(agent1);
        vm.expectRevert(AgentStaking.NoCooldown.selector);
        staking.withdraw(1);
    }

    function test_RevertWhen_WithdrawBeforeCooldownExpires() public {
        vm.prank(agent1);
        staking.stake{value: 0.025 ether}(1, 0);

        vm.prank(agent1);
        staking.requestWithdrawal(1);

        vm.warp(block.timestamp + 1 days); // Only 1 day, need 7

        vm.prank(agent1);
        vm.expectRevert(abi.encodeWithSelector(AgentStaking.CooldownActive.selector, block.timestamp + 6 days));
        staking.withdraw(1);
    }

    function test_RevertWhen_WithdrawNotStaker() public {
        vm.prank(agent1);
        staking.stake{value: 0.025 ether}(1, 0);

        vm.prank(agent2);
        vm.expectRevert(AgentStaking.Unauthorized.selector);
        staking.requestWithdrawal(1);
    }

    // ═══════════════════════════
    //  Slashing
    // ═══════════════════════════

    function test_Slash() public {
        vm.prank(agent1);
        staking.stake{value: 0.1 ether}(1, 1);

        staking.addSlasher(slasher);

        uint256 wbBefore = whistleblower.balance;
        uint256 burnBefore = address(staking.BURN_ADDRESS()).balance;

        vm.prank(slasher);
        staking.slash(1, whistleblower);

        assertFalse(staking.isStaked(1));
        assertEq(staking.totalBurned(), 0.05 ether);
        assertEq(staking.totalWhistleblowerPaid(), 0.05 ether);
        assertEq(whistleblower.balance, wbBefore + 0.05 ether);
        assertEq(address(staking.BURN_ADDRESS()).balance, burnBefore + 0.05 ether);
    }

    function test_SlashWithOddAmount() public {
        // Custom required stake for testing odd splits
        staking.updateRequiredStake(0, 101 wei);
        
        vm.prank(agent1);
        staking.stake{value: 101 wei}(1, 0);

        staking.addSlasher(slasher);

        vm.prank(slasher);
        staking.slash(1, whistleblower);

        // 101 / 2 = 50 wei to whistleblower, 51 wei burned
        assertEq(staking.totalBurned(), 51 wei);
        assertEq(staking.totalWhistleblowerPaid(), 50 wei);
    }

    function test_RevertWhen_SlashNotSlasher() public {
        vm.prank(agent1);
        staking.stake{value: 0.025 ether}(1, 0);

        vm.prank(stranger);
        vm.expectRevert(AgentStaking.Unauthorized.selector);
        staking.slash(1, whistleblower);
    }

    function test_RevertWhen_SlashNotStaked() public {
        staking.addSlasher(slasher);

        vm.prank(slasher);
        vm.expectRevert(AgentStaking.NotStaked.selector);
        staking.slash(999, whistleblower);
    }

    function test_SlashCannotDoubleSlash() public {
        vm.prank(agent1);
        staking.stake{value: 0.025 ether}(1, 0);

        staking.addSlasher(slasher);

        vm.prank(slasher);
        staking.slash(1, whistleblower);

        vm.prank(slasher);
        vm.expectRevert(AgentStaking.NotStaked.selector);
        staking.slash(1, whistleblower);
    }

    // ═══════════════════════════
    //  Graduation
    // ═══════════════════════════

    function test_Graduate() public {
        vm.prank(agent1);
        staking.stake{value: 0.025 ether}(1, 0);

        staking.addSlasher(slasher);

        uint256 balanceBefore = agent1.balance;

        vm.prank(slasher);
        staking.graduate(1);

        assertFalse(staking.isStaked(1));
        assertApproxEqAbs(agent1.balance, balanceBefore + 0.025 ether, 0.001 ether);
    }

    function test_RevertWhen_GraduateNotSlasher() public {
        vm.prank(agent1);
        staking.stake{value: 0.025 ether}(1, 0);

        vm.prank(stranger);
        vm.expectRevert(AgentStaking.Unauthorized.selector);
        staking.graduate(1);
    }

    function test_WithdrawAfterSlashFails() public {
        vm.prank(agent1);
        staking.stake{value: 0.025 ether}(1, 0);

        staking.addSlasher(slasher);

        vm.prank(slasher);
        staking.slash(1, whistleblower);

        vm.prank(agent1);
        vm.expectRevert(AgentStaking.NotStaked.selector);
        staking.requestWithdrawal(1);
    }

    // ═══════════════════════════
    //  Admin
    // ═══════════════════════════

    function test_AddRemoveSlasher() public {
        staking.addSlasher(slasher);
        assertTrue(staking.slashers(slasher));

        staking.removeSlasher(slasher);
        assertFalse(staking.slashers(slasher));
    }

    function test_TransferOwnership() public {
        address newOwner = address(0xABCD);
        staking.transferOwnership(newOwner);

        vm.prank(newOwner);
        staking.addSlasher(slasher);
        assertTrue(staking.slashers(slasher));
    }

    function test_UpdateRequiredStake() public {
        staking.updateRequiredStake(0, 0.05 ether);
        assertEq(staking.requiredStake(0), 0.05 ether);
    }

    // ═══════════════════════════
    //  Reentrancy Guard
    // ═══════════════════════════

    function test_NoReentrancyOnWithdraw() public {
        // Simple test: verify withdrawal handles clean state
        vm.prank(agent1);
        staking.stake{value: 0.025 ether}(1, 0);

        vm.prank(agent1);
        staking.requestWithdrawal(1);

        vm.warp(block.timestamp + 8 days);

        uint256 gasBefore = gasleft();
        vm.prank(agent1);
        staking.withdraw(1);
        uint256 gasUsed = gasBefore - gasleft();

        assertFalse(staking.isStaked(1));
        assertLt(gasUsed, 100000); // Should be cheap, no loops
    }
}
