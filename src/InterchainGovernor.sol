// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IAxelarGateway} from "@axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import {IAxelarGasService} from "@axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {AxelarExecutable} from "@axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract InterchainGovernor is
    Governor,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl,
    AxelarExecutable,
    Ownable
{
    struct Council {
        string chainId;
        string addr;
    }

    Council[] public councils;
    IAxelarGasService public gasService;

    constructor(
        string[] memory chainIds,
        string[] memory councils_,
        string memory name,
        address gateway_,
        IAxelarGasService gasService_,
        IVotes _token,
        TimelockController _timelock
    ) AxelarExecutable(gateway_) Governor(name) GovernorVotes(_token) GovernorVotesQuorumFraction(4) GovernorTimelockControl(_timelock) Ownable(msg.sender) {
        gasService = gasService_;
        setCouncil(chainIds, councils_);
    }

    function setCouncil(string[] memory chainIds, string[] memory councils_) public onlyOwner {
        require(chainIds.length == councils_.length, "Invalid council length");
        for (uint256 i = 0; i < chainIds.length; i++) {
            councils.push(Council(chainIds[i], councils_[i]));
        }
    }

    function removeCouncil(uint256 chainId) public onlyOwner {
        delete councils[chainId];
    }

    function votingDelay() public pure override returns (uint256) {
        return 7200; // 1 day
    }

    function votingPeriod() public pure override returns (uint256) {
        return 50400; // 1 week
    }

    function proposalThreshold() public pure override returns (uint256) {
        return 0;
    }

    function propose (
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override returns (uint256 proposalId) {
        proposalId = super.propose(targets, values, calldatas, description);

        bytes memory encoded = abi.encodePacked(this.propose.selector, abi.encode(targets, values, calldatas, description));
        for (uint256 i = 0; i < councils.length; i++) {
            Council memory council = councils[i];
            gateway.callContract(council.chainId, council.addr, encoded);
        }
    }

    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable override(Governor) returns (uint256 proposalId) {
        proposalId = super.execute(targets, values, calldatas, descriptionHash);

        bytes memory encoded = abi.encodePacked(Governor.execute.selector, abi.encode(targets, values, calldatas, descriptionHash));
        for (uint256 i = 0; i < councils.length; i++) {
            Council memory council = councils[i];
            gateway.callContract(council.chainId, council.addr, encoded);
        }
    }

    // The functions below are overrides required by Solidity.
    function state(uint256 proposalId) public view override(Governor, GovernorTimelockControl) returns (ProposalState) {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(
        uint256 proposalId
    ) public view virtual override(Governor, GovernorTimelockControl) returns (bool) {
        return super.proposalNeedsQueuing(proposalId);
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }

    function _execute(
        string calldata sourceChain_, string calldata sourceAddress_, bytes calldata payload_
    ) internal override(AxelarExecutable) {
        // TODO: Implement guard for parent only execution

        (bool ok, ) = address(this).staticcall(payload_);
        require(ok, "InterchainGovernor: execution failed");
    }
}
