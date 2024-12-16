// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {FeatureFlashMintAndPermit} from "./demo2.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FMandPFactory is Ownable{
    address[] public deployedContracts;
    IERC20 public feeToken;
    uint256 public deploymentFee;
    address feeCollector;

    event ContractDeployed(address contractAddress);

    constructor(
        address _feeToken, 
        uint256 _deploymentFee,
        address _feeCollector
    ) Ownable(msg.sender) {
        feeToken = IERC20(_feeToken);
        deploymentFee = _deploymentFee;
        feeCollector = _feeCollector;
    }

    function deployContract(
        address _initialOwner,
        string memory _name,
        string memory _symbol,
        bool _isMintable,
        bool _isBurnable,
        bool _isPausable,
        uint256 _premintAmount
    ) public {
        address newContract = address(
            new FeatureFlashMintAndPermit(
                _initialOwner,
                _name,
                _symbol,
                _isMintable,
                _isBurnable,
                _isPausable,
                _premintAmount
            )
        );

        deployedContracts.push(newContract);
        transferFee();
        emit ContractDeployed(newContract);
    }
    

    function transferFee() internal {
        feeToken.transferFrom(msg.sender, feeCollector, deploymentFee);
    }

    function updateDeploymentFee(uint256 _newFee) external onlyOwner {
        deploymentFee = _newFee;
    }

    function updateFeeToken(IERC20 _newFeeToken) external onlyOwner {
        feeToken = _newFeeToken;
    }

    function updateFeeCollector(address _newFeeCollector) external onlyOwner {
        feeCollector = _newFeeCollector;
    }

    function getDeployedContracts() public view returns (address[] memory) {
        return deployedContracts;
    }
}