// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IAxelarGateway} from "@axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import {AxelarExecutable} from "@axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IAxelarGasService} from "@axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract MockGovernor is Ownable, AxelarExecutable {
    struct Council {
        string chainId;
        string addr;
    }

    IAxelarGasService public gasService;
    Council public parent;
    uint256 public childrenCount;
    string public govName;
    mapping(uint256 => Council) public children;

    constructor(
        IAxelarGateway gateway_,
        IAxelarGasService gasService_,
        IVotes _token,
        TimelockController _timelock,
        string memory name
    ) Ownable(msg.sender) AxelarExecutable(address(gateway_)) {
        govName = name;
        gasService = gasService_;
    }

    function setParent(Council memory parent_) public onlyOwner {
        require(childrenCount == 0, "setParent fail: child can't have children");
        parent = parent_;
    }

    function setCouncil(Council[] memory councils) public onlyOwner {
        Council memory emptyCouncil;
        require(keccak256(abi.encode(parent)) == keccak256(abi.encode(emptyCouncil)), "setCouncil fail: parent can't have parent");
        childrenCount = councils.length;
        for (uint256 i = 0; i < councils.length; i++) {
            children[i] = councils[i];
        }
    }
}
