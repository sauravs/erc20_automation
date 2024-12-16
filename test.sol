
write full end to end solidity test incuding revert condition  in foundry framework for BaseFactory Contract:


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {FeatureBasedContract} from "./demo2.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BaseFactory is Ownable{
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
            new FeatureBasedContract(
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


where demo2.sol has following code :

// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20FlashMint} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract FeatureBasedContract is ERC20, ERC20Burnable, ERC20Pausable, Ownable {
    struct Features {
        bool isMintable;
        bool isBurnable;
        bool isPausable;
    }

    Features public features;

    constructor(
        address initialOwner,
        string memory name,
        string memory symbol,
        bool _isMintable,
        bool _isBurnable,
        bool _isPausable,
        uint256 _premintAmount
    ) ERC20(name, symbol) Ownable(initialOwner) {
        features = Features({
            isMintable: _isMintable,
            isBurnable: _isBurnable,
            isPausable: _isPausable
        });
        _mint(initialOwner, _premintAmount);
    }

    modifier featureEnabled(bool isTrue) {
        require(isTrue, "Feature is not enabled");
        _;
    }

    function mint(address to, uint256 amount)
        public
        onlyOwner
        featureEnabled(features.isMintable)
    {
        _mint(to, amount);
    }

    function burn(uint256 amount)
        public
        override
        featureEnabled(features.isBurnable)
    {
        super.burn(amount);
    }

    function pause() public onlyOwner featureEnabled(features.isPausable) {
        _pause();
    }

    function unpause() public onlyOwner featureEnabled(features.isPausable) {
        _unpause();
    }

    function _update(
        address from,
        address to,
        uint256 value
    )
        internal
        virtual
        override(ERC20, ERC20Pausable)
        featureEnabled(features.isPausable)
    {
        super._update(from, to, value);
    }
}
