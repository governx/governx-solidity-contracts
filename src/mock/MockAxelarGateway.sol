// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAxelarGateway} from "@axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";

contract MockAxelarGateway is IAxelarGateway, Ownable {

    constructor() Ownable(msg.sender) {}

    function allTokensFrozen() external view returns (bool) {}
    function authModule() external view returns (address) {}
    function callContractWithToken(
        string calldata destinationChain,
        string calldata contractAddress,
        bytes calldata payload,
        string calldata symbol,
        uint256 amount
    ) external {}
    function contractId() external pure returns (bytes32) {}
    function governance() external view returns (address) {}
    function implementation() external view returns (address) {}
    function isCommandExecuted(bytes32 commandId) external view returns (bool) {}
    function isContractCallAndMintApproved(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        address contractAddress,
        bytes32 payloadHash,
        string calldata symbol,
        uint256 amount
    ) external view returns (bool) {}
    function isContractCallApproved(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        address contractAddress,
        bytes32 payloadHash
    ) external view returns (bool) {}
    function mintLimiter() external view returns (address) {}
    function sendToken(
        string calldata destinationChain,
        string calldata destinationAddress,
        string calldata symbol,
        uint256 amount
    ) external {}
    function setTokenMintLimits(string[] calldata symbols, uint256[] calldata limits) external {}
    function setup(bytes calldata data) external {}
    function tokenAddresses(string memory symbol) external view returns (address) {}
    function tokenDeployer() external view returns (address) {}
    function tokenFrozen(string memory symbol) external view returns (bool) {}
    function tokenMintAmount(string memory symbol) external view returns (uint256) {}
    function tokenMintLimit(string memory symbol) external view returns (uint256) {}
    function transferGovernance(address newGovernance) external {}
    function transferMintLimiter(address newGovernance) external {}
    function upgrade(
        address newImplementation,
        bytes32 newImplementationCodeHash,
        bytes calldata setupParams
    ) external {}
    function validateContractCallAndMint(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes32 payloadHash,
        string calldata symbol,
        uint256 amount
    ) external returns (bool) {}
    function execute(bytes calldata input) external onlyOwner {}

    function validateContractCall(
        bytes32 commandId,
        string calldata sourceChain,
        string calldata sourceAddress,
        bytes32 payloadHash
    ) external returns (bool) {
        return true;
    }

    function callContract(
        string calldata destinationChain,
        string calldata destinationContractAddress,
        bytes calldata payload
    ) external {
        emit ContractCall(msg.sender, destinationChain, destinationContractAddress, keccak256(payload), payload);
    }
}
