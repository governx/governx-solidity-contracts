// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

//import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
//import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
//import {GovernorVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
//import {GovernorVotesQuorumFraction} from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
//import {GovernorTimelockControl} from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
//import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
//import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
//import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IAxelarGateway} from "@axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import {IAxelarGasService} from "@axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {AxelarExecutable} from "@axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
//import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract InterchainSenate is
    AxelarExecutable
{
    struct Governor {
        string chainID;
        string addr;
    }

    struct InterchainProposal {
        uint256 proposalId;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        string description;
    }

    string public capitalChainID;
    Governor[] public governors;
    IAxelarGasService public gasService;
    address public governorFactory;

    mapping (int64 proposalId => bytes) public proposalData;

    constructor(
        string memory capitalChainID_,
        string[] memory chainIDs,
        string[] memory addresses,
        address gateway_,
        IAxelarGasService gasService_,
        address governorFactory_
    ) AxelarExecutable(gateway_) {
        gasService = gasService_;
        governorFactory = governorFactory_;
        require(chainIDs.length == addresses.length, "Invalid chainIDs length");
        for (uint256 i = 0; i < chainIDs.length; i++) {
            governors.push(Governor(chainIDs[i], addresses[i]));
        }
    }

    function setGovernor(string[] memory chainIDs, string[] memory councils_) public {
        require(chainIDs.length == councils_.length, "Invalid council length");
        require(msg.sender == governorFactory, "caller not allowed");
        for (uint256 i = 0; i < chainIDs.length; i++) {
            governors.push(Governor(chainIDs[i], councils_[i]));
        }
    }

    function removeGovernor(uint256 chainID) public {
        delete governors[chainID];
    }

    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public override returns (uint256 proposalId) {
        proposalId = super.propose(targets, values, calldatas, description);

        bytes memory encoded = abi.encode(
            uint8(0), // Propose
            abi.encode(abi.encode(targets, values, calldatas, description))
        );

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
        require(_isCouncil(sourceChain_, sourceAddress_), "caller not allowed");
        (uint8 option, bytes memory data) = abi.decode(payload_, (uint8, bytes));
        if (option == uint8(0)) {
            // Set council
            revert("not implemented");
        } else if (option == uint8(1)) {
            // Set council vote
            revert("not implemented");
        } else {
            revert("execute fail: unknown option");
        }
    }

    function _isCouncil(string calldata sourceChain_, string calldata sourceAddress_) internal view returns (bool) {
        for (uint256 i = 0; i < councils.length; i++) {
            Council memory council = councils[i];
            if (council.chainId == sourceChain_ && council.addr == sourceAddress_) {
                return true;
            }
        }
        return false;
    }
}
