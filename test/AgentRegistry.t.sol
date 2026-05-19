// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AgentRegistry.sol";

contract AgentRegistryTest is Test {
    AgentRegistry public registry;

    address public agent1 = address(0x1001);
    address public agent2 = address(0x1002);
    address public attestor = address(0x2001);
    address public stranger = address(0x9999);

    event AgentRegistered(
        uint256 indexed agentId,
        address indexed agentWallet,
        string name,
        uint256 timestamp
    );
    event ReputationUpdated(
        uint256 indexed agentId,
        uint256 newScore,
        address indexed attestor
    );

    function setUp() public {
        registry = new AgentRegistry();
        vm.label(address(registry), "AgentRegistry");
        vm.label(agent1, "Agent1");
        vm.label(agent2, "Agent2");
        vm.label(attestor, "Attestor");
        vm.label(stranger, "Stranger");
    }

    // ═══════════════════════════
    //  Registration
    // ═══════════════════════════

    function test_RegisterAgent() public {
        vm.prank(agent1);
        uint256 id = registry.registerAgent("Panini", "translation,trading,monitoring", "ipfs://QmTest");

        assertEq(id, 1);
        assertEq(registry.agentCount(), 1);

        AgentRegistry.Agent memory agent = registry.getAgent(1);
        assertEq(agent.id, 1);
        assertEq(agent.agentWallet, agent1);
        assertEq(agent.name, "Panini");
        assertEq(agent.capabilities, "translation,trading,monitoring");
        assertEq(agent.metadataURI, "ipfs://QmTest");
        assertEq(agent.reputationScore, 100);
        assertTrue(agent.active);
    }

    function test_RegisterAgent_EmitsEvent() public {
        vm.prank(agent1);
        vm.expectEmit(true, true, false, true);
        emit AgentRegistered(1, agent1, "Panini", block.timestamp);
        registry.registerAgent("Panini", "test", "");
    }

    function test_RevertWhen_NameEmpty() public {
        vm.prank(agent1);
        vm.expectRevert(AgentRegistry.InvalidName.selector);
        registry.registerAgent("", "test", "");
    }

    function test_RevertWhen_AlreadyRegistered() public {
        vm.prank(agent1);
        registry.registerAgent("Panini", "test", "");

        vm.prank(agent1);
        vm.expectRevert(abi.encodeWithSelector(AgentRegistry.AgentAlreadyRegistered.selector, agent1));
        registry.registerAgent("Panini2", "more", "");
    }

    function test_RegisterMultipleAgents() public {
        vm.prank(agent1);
        registry.registerAgent("Agent One", "skill1", "");

        vm.prank(agent2);
        uint256 id2 = registry.registerAgent("Agent Two", "skill2", "ipfs://QmTwo");

        assertEq(id2, 2);
        assertEq(registry.agentCount(), 2);
        assertEq(registry.getAgentByWallet(agent1), 1);
        assertEq(registry.getAgentByWallet(agent2), 2);
        assertEq(registry.getAgentByWallet(stranger), 0);
    }

    // ═══════════════════════════
    //  Update Agent
    // ═══════════════════════════

    function test_UpdateAgent() public {
        vm.prank(agent1);
        registry.registerAgent("Original", "a,b", "ipfs://QmOld");

        vm.prank(agent1);
        registry.updateAgent(1, "Updated", "c,d,e", "ipfs://QmNew");

        AgentRegistry.Agent memory agent = registry.getAgent(1);
        assertEq(agent.name, "Updated");
        assertEq(agent.capabilities, "c,d,e");
        assertEq(agent.metadataURI, "ipfs://QmNew");
    }

    function test_RevertWhen_UpdateNotOwner() public {
        vm.prank(agent1);
        registry.registerAgent("Agent1", "test", "");

        vm.prank(agent2);
        vm.expectRevert(abi.encodeWithSelector(AgentRegistry.NotAgentOwner.selector, 1, agent2));
        registry.updateAgent(1, "Hacked", "evil", "");
    }

    function test_RevertWhen_UpdateInactiveAgent() public {
        vm.prank(agent1);
        registry.registerAgent("Agent1", "test", "");

        vm.prank(agent1);
        registry.deactivateAgent(1);

        vm.prank(agent1);
        vm.expectRevert(abi.encodeWithSelector(AgentRegistry.AgentNotActive.selector, 1));
        registry.updateAgent(1, "New", "test", "");
    }

    // ═══════════════════════════
    //  Activate / Deactivate
    // ═══════════════════════════

    function test_DeactivateAndReactivate() public {
        vm.prank(agent1);
        registry.registerAgent("Agent", "test", "");

        assertTrue(registry.isActive(1));

        vm.prank(agent1);
        registry.deactivateAgent(1);
        assertFalse(registry.isActive(1));

        vm.prank(agent1);
        registry.reactivateAgent(1);
        assertTrue(registry.isActive(1));
    }

    function test_RevertWhen_DeactivateNotOwner() public {
        vm.prank(agent1);
        registry.registerAgent("Agent", "test", "");

        vm.prank(agent2);
        vm.expectRevert(abi.encodeWithSelector(AgentRegistry.NotAgentOwner.selector, 1, agent2));
        registry.deactivateAgent(1);
    }

    // ═══════════════════════════
    //  Reputation
    // ═══════════════════════════

    function test_UpdateReputation() public {
        vm.prank(agent1);
        registry.registerAgent("Agent", "test", "");

        registry.addAttestor(attestor);

        vm.prank(attestor);
        registry.updateReputation(1, 500);

        assertEq(registry.getReputation(1), 500);
    }

    function test_AddReputationDelta() public {
        vm.prank(agent1);
        registry.registerAgent("Agent", "test", "");

        registry.addAttestor(attestor);

        vm.prank(attestor);
        registry.addReputationDelta(1, 50);
        assertEq(registry.getReputation(1), 150);

        vm.prank(attestor);
        registry.addReputationDelta(1, 200);
        assertEq(registry.getReputation(1), 350);
    }

    function test_RevertWhen_ReputationNotAttestor() public {
        vm.prank(agent1);
        registry.registerAgent("Agent", "test", "");

        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSelector(AgentRegistry.NotAttestor.selector, stranger));
        registry.updateReputation(1, 999);
    }

    function test_RevertWhen_ReputationOnInactive() public {
        vm.prank(agent1);
        registry.registerAgent("Agent", "test", "");

        registry.addAttestor(attestor);

        vm.prank(agent1);
        registry.deactivateAgent(1);

        vm.prank(attestor);
        vm.expectRevert(abi.encodeWithSelector(AgentRegistry.AgentNotActive.selector, 1));
        registry.updateReputation(1, 500);
    }

    function test_ReputationEmitsEvent() public {
        vm.prank(agent1);
        registry.registerAgent("Agent", "test", "");

        registry.addAttestor(attestor);

        vm.prank(attestor);
        vm.expectEmit(true, true, true, false);
        emit ReputationUpdated(1, 500, attestor);
        registry.updateReputation(1, 500);
    }

    // ═══════════════════════════
    //  Attestor Management
    // ═══════════════════════════

    function test_AddAttestor() public {
        registry.addAttestor(attestor);
        assertTrue(registry.attestors(attestor));
    }

    function test_RemoveAttestor() public {
        registry.addAttestor(attestor);
        registry.removeAttestor(attestor);
        assertFalse(registry.attestors(attestor));
    }

    function test_RevertWhen_AddAttestorNotOwner() public {
        vm.prank(stranger);
        vm.expectRevert(AgentRegistry.Unauthorized.selector);
        registry.addAttestor(attestor);
    }

    // ═══════════════════════════
    //  Ownership
    // ═══════════════════════════

    function test_TransferOwnership() public {
        address newOwner = address(0xABCD);
        registry.transferOwnership(newOwner);

        // Old owner cannot manage attestors
        vm.expectRevert(AgentRegistry.Unauthorized.selector);
        registry.addAttestor(attestor);

        // New owner can
        vm.prank(newOwner);
        registry.addAttestor(attestor);
        assertTrue(registry.attestors(attestor));
    }

    // ═══════════════════════════
    //  Edge Cases
    // ═══════════════════════════

    function test_QueryNonexistentAgent() public {
        vm.expectRevert(abi.encodeWithSelector(AgentRegistry.AgentNotRegistered.selector, 999));
        registry.getAgent(999);
    }

    function test_QueryAgentZero() public {
        vm.expectRevert(abi.encodeWithSelector(AgentRegistry.AgentNotRegistered.selector, 0));
        registry.getAgent(0);
    }

    function test_ManyRegistrations() public {
        for (uint256 i = 0; i < 20; i++) {
            address a = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
            vm.prank(a);
            registry.registerAgent(
                string(abi.encodePacked("Agent", vm.toString(i))),
                "test",
                ""
            );
        }
        assertEq(registry.agentCount(), 20);
        assertTrue(registry.isActive(1));
        assertTrue(registry.isActive(20));
    }
}
