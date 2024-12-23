// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {FeatureFlashMintAndPermit} from "./CodeSnippet.sol";

/// @title PermitAndFMFactory - Factory contract for deploying ERC20 tokens with basic features 1)mint 2)burn 3)pause 4) basic access control 5)Gassless permit 6)Flash Mint

/// @notice This contract allows users to deploy new ERC20 tokens with configurable features
/// @dev Inherits from Ownable for access control

contract PermitAndFMFactory is Ownable {
    using SafeERC20 for IERC20;

    /// @notice Token used for paying deployment fees
    IERC20 public feeToken;

    /// @notice Address that collects deployment fees
    address public feeCollector;

    /// @notice Fee required to deploy a new token
    uint256 public deploymentFee;

    /// @notice Array of all deployed contract addresses
    /// @dev Made private as external access is provided through getter
    address[] private deployedContracts;

    /// @notice Error thrown when contract deployment fail
    error DeploymentFailed();
    /// @notice Error thrown when max supply is set to zero
    error MaxSupplyTooLow();
    /// @notice Error thrown when initial supply exceeds max supply
    error InitialSupplyExceedsMax();

    /// @notice Error thrown when zero address is provided
    error InvalidAddress();

    /// @notice Emitted when a new contract is deployed
    /// @param contractAddress The address of the newly deployed contract
    event ContractDeployed(address indexed contractAddress);

    /// @notice Initializes the factory with required parameters
    /// @param _feeToken Address of the token used for deployment fees
    /// @param _deploymentFee Amount of tokens required for deployment
    /// @param _feeCollector Address that receives deployment fees
    constructor(address _feeToken, uint256 _deploymentFee, address _feeCollector) Ownable(msg.sender) {
        feeToken = IERC20(_feeToken);
        deploymentFee = _deploymentFee;
        feeCollector = _feeCollector;
    }

    /// @notice Deploys a new token contract with specified parameters
    /// @param _initialOwner Address that will own the deployed token
    /// @param _name Name of the token
    /// @param _symbol Symbol of the token
    /// @param _isBurnable Whether the token can be burned
    /// @param _isPausable Whether the token can be paused
    /// @param _premintAmount Amount of tokens to mint at deployment
    /// @param _maxSupply Maximum possible supply of the token
    /// @return Address of the deployed contract
    /// @dev Validates inputs, deploys contract, verifies deployment, and handles fee
    function deployContract(
        address _initialOwner,
        string calldata _name,
        string calldata _symbol,
        bool _isMintable,
        bool _isBurnable,
        bool _isPausable,
        bool _hasMaxSupply,
        uint256 _premintAmount,
        uint256 _maxSupply
    ) external returns (address) {
        if (_maxSupply == 0) revert MaxSupplyTooLow();
        if (_premintAmount > _maxSupply) revert InitialSupplyExceedsMax();

        FeatureFlashMintAndPermit newContract = new FeatureFlashMintAndPermit(
            _initialOwner,
            _name,
            _symbol,
            _isMintable,
            _isBurnable,
            _isPausable,
            _hasMaxSupply,
            _premintAmount,
            _maxSupply
        );

        if (!isContractDeployed(address(newContract))) {
            revert DeploymentFailed();
        }

        feeToken.safeTransferFrom(msg.sender, feeCollector, deploymentFee);

        deployedContracts.push(address(newContract));
        emit ContractDeployed(address(newContract));

        return address(newContract);
    }

    /// @notice Checks if a contract exists at the given address
    /// @param _contract Address to check
    /// @return bool True if contract exists, false otherwise
    /// @dev Uses assembly to check contract size
    function isContractDeployed(address _contract) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_contract)
        }
        return size > 0;
    }

    /// @notice Updates the deployment fee
    /// @param _newFee New fee amount
    /// @dev Only callable by owner
    function updateDeploymentFee(uint256 _newFee) external onlyOwner {
        deploymentFee = _newFee;
    }

    /// @notice Updates the fee token
    /// @param _newFeeToken New fee token address
    /// @dev Only callable by owner

    function updateFeeToken(IERC20 _newFeeToken) external onlyOwner {
        if (address(_newFeeToken) == address(0)) revert InvalidAddress();
        feeToken = _newFeeToken;
    }

    /// @notice Updates the fee collector
    /// @param _newFeeCollector New fee collector address
    /// @dev Only callable by owner

    function updateFeeCollector(address _newFeeCollector) external onlyOwner {
        if (_newFeeCollector == address(0)) revert InvalidAddress();
        feeCollector = _newFeeCollector;
    }

    /// @notice Gets all deployed contract addresses
    /// @return Array of deployed contract addresses
    function getDeployedContracts() external view returns (address[] memory) {
        return deployedContracts;
    }
}
