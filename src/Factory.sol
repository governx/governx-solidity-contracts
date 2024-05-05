// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import {IAxelarGateway} from "@axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import {IAxelarGasService} from "@axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {AxelarExecutable} from "@axelar-gmp-sdk-solidity/contracts/executable/AxelarExecutable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {StringToAddress, AddressToString} from "@axelar-gmp-sdk-solidity/contracts/libs/AddressString.sol";
import {MockGovernor} from "./mock/MockGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract Factory is AxelarExecutable, Ownable {
    using StringToAddress for string;
    using AddressToString for address;

    struct Task {
        bool isInitialized;
        uint256 totalChildren;
        MockGovernor parent;
        mapping(bytes32 => bool) markForCallback;
        MockGovernor.Council[] children;
    }

    IAxelarGasService public gasService;
    uint256 public nonce;
    mapping(uint256 => Task) public tasks;

    constructor(
        address gateway_,
        IAxelarGasService gasService_
    ) AxelarExecutable(gateway_) Ownable(msg.sender) {
        gasService = gasService_;
    }

    function getRemoteFactoryKey(
        string memory chainID,
        string memory factoryAddressStr
    ) public pure returns (bytes32 key) {
        key = keccak256(abi.encodePacked(chainID, factoryAddressStr));
    }

    function newGovOrigin(
        IVotes token,
        TimelockController timelock,
        string[] memory remoteFactories,
        string[] memory remoteChainIDs,
        IVotes[] memory remoteTokens,
        TimelockController[] memory remoteTimelocks,
        string memory govName
    ) external {
        nonce++;
        uint256 remoteCount = remoteFactories.length;
        require(
            remoteChainIDs.length == remoteCount,
            "newGovOrigin fail: invalid size for remoteChainIDs"
        );
        require(
            remoteTokens.length == remoteCount,
            "newGovOrigin fail: invalid size for remoteTokens"
        );
        require(
            remoteTimelocks.length == remoteCount,
            "newGovOrigin fail: invalid size for remoteTimelocks"
        );

        // TODO Add paying gas for Axelar

        MockGovernor parent = new MockGovernor(
            gateway,
            gasService,
            token,
            timelock,
            govName
        );
        Task storage t = tasks[nonce];
        t.parent = parent;
        t.totalChildren = remoteCount;
        if (remoteCount == 0) {
            _initGov(nonce);
        }
        for (uint256 i = 0; i < remoteCount; i++) {
            t.markForCallback[
                getRemoteFactoryKey(remoteChainIDs[i], remoteFactories[i])
            ] = true;
            gateway.callContract(
                remoteChainIDs[i],
                remoteFactories[i],
                abi.encode(
                    uint8(0),
                    abi.encode(
                        nonce,
                        parent,
                        remoteTokens[i],
                        remoteTimelocks[i],
                        govName
                    )
                )
            );
        }
    }

    function _newGovRemote(
        string memory sourceChain_,
        string memory sourceAddress_,
        bytes memory data
    ) internal {
        (
            uint256 sourceNonce,
            address parent,
            IVotes token,
            TimelockController timelock,
            string memory govName
        ) = abi.decode(
                data,
                (uint256, address, IVotes, TimelockController, string)
            );
        MockGovernor mg = new MockGovernor(
            gateway,
            gasService,
            token,
            timelock,
            govName
        );
        mg.setParent(MockGovernor.Council(sourceChain_, parent.toString()));
        gateway.callContract(
            sourceChain_,
            sourceAddress_,
            abi.encode(uint8(1), abi.encode(mg, sourceNonce))
        );
    }

    function _receiveCreationCallback(
        string memory sourceChain_,
        string memory sourceAddress_,
        bytes memory data
    ) internal {
        (address childAddress, uint256 sourceNonce) = abi.decode(
            data,
            (address, uint256)
        );
        Task storage t = tasks[sourceNonce];
        bytes32 key = getRemoteFactoryKey(sourceChain_, sourceAddress_);
        require(
            t.markForCallback[key],
            "_receiveCreationCallback fail: no waiting for callback"
        );
        t.markForCallback[key] = false;
        t.children.push(
            MockGovernor.Council(sourceChain_, childAddress.toString())
        );
        if (t.totalChildren == t.children.length) {
            _initGov(sourceNonce);
        }
    }

    function _initGov(uint256 taskNonce) internal {
        Task storage t = tasks[taskNonce];
        require(
            t.isInitialized == false,
            "_initGov fail: task has been initialized"
        );
        require(address(t.parent) != address(0), "_initGov fail: empty task");
        t.isInitialized = true;
        uint256 len = t.children.length;
        MockGovernor.Council[] memory children = new MockGovernor.Council[](
            len
        );
        for (uint256 i = 0; i < len; i++) {
            children[i] = t.children[i];
        }
        t.parent.setCouncil(children);
    }

    function _execute(
        string calldata sourceChain_,
        string calldata sourceAddress_,
        bytes calldata payload
    ) internal override(AxelarExecutable) {
        (uint8 option, bytes memory data) = abi.decode(payload, (uint8, bytes));
        if (option == uint8(0)) {
            _newGovRemote(sourceChain_, sourceAddress_, data);
        } else if (option == uint8(1)) {
            _receiveCreationCallback(sourceChain_, sourceAddress_, data);
        } else {
            revert("_execute fail: unknown option");
        }
    }
}
