// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import {ERC20FlashMint} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/// @title Basic Feature Contract with configurable features
/// @notice ERC20 token with fully configurable features including minting and max supply
/// @dev Inherits from ERC20, ERC20Burnable, ERC20Pausable and Ownable
contract BasicFeatureContract is ERC20, ERC20Burnable, ERC20Pausable, Ownable {
    /// @notice Maximum possible token supply, zero means unlimited
    uint256 public immutable maxSupply;

    /// @notice Struct for features, packed into single storage slot
    struct Features {
        bool isMintable;
        bool isBurnable;
        bool isPausable;
        bool hasMaxSupply;
    }

    /// @notice Current feature configuration
    Features public features;

    /// @dev Custom errors for gas optimization
    error MaxSupplyExceeded(uint256 requested, uint256 maxSupply);
    error FeatureNotEnabled(string feature);
    error InvalidMaxSupplyConfig();

    /// @notice Initializes the token with configurable features
    /// @param initialOwner Address of the token owner
    /// @param name Token name
    /// @param symbol Token symbol
    /// @param _isMintable Whether tokens can be minted
    /// @param _isBurnable Whether tokens can be burned
    /// @param _isPausable Whether transfers can be paused
    /// @param _hasMaxSupply Whether to enforce max supply
    /// @param _premintAmount Initial token supply
    /// @param _maxSupply Maximum supply (if hasMaxSupply is true)
    constructor(
        address initialOwner,
        string memory name,
        string memory symbol,
        bool _isMintable,
        bool _isBurnable,
        bool _isPausable,
        bool _hasMaxSupply,
        uint256 _premintAmount,
        uint256 _maxSupply
    ) ERC20(name, symbol) Ownable(initialOwner) {
        // Validate max supply configuration
        if (_hasMaxSupply) {
            if (_maxSupply == 0 || _premintAmount > _maxSupply) {
                revert InvalidMaxSupplyConfig();
            }
        }

        features = Features({
            isMintable: _isMintable,
            isBurnable: _isBurnable,
            isPausable: _isPausable,
            hasMaxSupply: _hasMaxSupply
        });

        // if hasMaxSupply is false, set maxSupply to type(uint256).max
        maxSupply = _hasMaxSupply ? _maxSupply : type(uint256).max;

        if (_premintAmount > 0) {
            _mint(initialOwner, _premintAmount);
        }
    }

    /// @notice Mints new tokens if minting is enabled
    /// @param to Recipient of minted tokens
    /// @param amount Amount to mint
    function mint(address to, uint256 amount) external onlyOwner {
        if (!features.isMintable) {
            revert FeatureNotEnabled("mint");
        }

        if (features.hasMaxSupply && totalSupply() + amount > maxSupply) {
            revert MaxSupplyExceeded(totalSupply() + amount, maxSupply);
        }

        _mint(to, amount);
    }

    /// @notice Burns tokens if burning is enabled
    /// @param amount Amount to burn
    function burn(uint256 amount) public override {
        if (!features.isBurnable) {
            revert FeatureNotEnabled("burn");
        }
        super.burn(amount);
    }

    /// @notice Pauses token transfers if pausable is enabled
    function pause() external onlyOwner {
        if (!features.isPausable) {
            revert FeatureNotEnabled("pause");
        }
        _pause();
    }

    /// @notice Unpauses token transfers if pausable is enabled
    function unpause() external onlyOwner {
        if (!features.isPausable) {
            revert FeatureNotEnabled("pause");
        }
        _unpause();
    }

    /// @notice Hook called before any transfer
    /// @dev Required override to handle pausable functionality

    function _update(address from, address to, uint256 value) internal virtual override(ERC20, ERC20Pausable) {
        if (!features.isPausable) {
            revert FeatureNotEnabled("pause");
        }
        super._update(from, to, value);
    }

    /// @notice Renounces ownership of the contract
    /// @dev Once ownership is renounced, it can never be claimed again
    function renounceOwnership() public virtual override onlyOwner {
        _transferOwnership(address(0));
    }

    /// @notice Gets current feature configuration
    /// @return Current Features struct
    function getFeatures() external view returns (Features memory) {
        return features;
    }
}

/// @title Feature Contract with Permit Support
/// @notice ERC20 token with permit functionality
/// @dev Inherits from BasicFeatureContract and adds ERC20Permit
contract FeaturePermit is BasicFeatureContract, ERC20Permit {
    /// @notice Initializes token with permit functionality
    /// @param initialOwner Address that will own the contract
    /// @param name Token name
    /// @param symbol Token symbol
    /// @param _isMintable Whether tokens can be minted
    /// @param _isBurnable Whether tokens can be burned
    /// @param _isPausable Whether transfers can be paused
    /// @param _hasMaxSupply Whether max supply is enforced
    /// @param _premintAmount Initial supply to mint
    /// @param _maxSupply Maximum token supply if enabled
    constructor(
        address initialOwner,
        string memory name,
        string memory symbol,
        bool _isMintable,
        bool _isBurnable,
        bool _isPausable,
        bool _hasMaxSupply,
        uint256 _premintAmount,
        uint256 _maxSupply
    )
        BasicFeatureContract(
            initialOwner,
            name,
            symbol,
            _isMintable,
            _isBurnable,
            _isPausable,
            _hasMaxSupply,
            _premintAmount,
            _maxSupply
        )
        ERC20Permit(name)
    {}

    /// @notice Internal update function required by ERC20
    /// @dev Overrides both BasicFeatureContract and ERC20
    function _update(address from, address to, uint256 value) internal virtual override(BasicFeatureContract, ERC20) {
        super._update(from, to, value);
    }
}

/// @title Feature Contract with Flash Mint Support
/// @notice ERC20 token with flash loan functionality
/// @dev Inherits from BasicFeatureContract and adds ERC20FlashMint
contract FeatureFlashMint is BasicFeatureContract, ERC20FlashMint {
    /// @notice Initializes token with flash mint functionality
    /// @param initialOwner Address that will own the contract
    /// @param name Token name
    /// @param symbol Token symbol
    /// @param _isMintable Whether tokens can be minted
    /// @param _isBurnable Whether tokens can be burned
    /// @param _isPausable Whether transfers can be paused
    /// @param _hasMaxSupply Whether max supply is enforced
    /// @param _premintAmount Initial supply to mint
    /// @param _maxSupply Maximum token supply if enabled
    constructor(
        address initialOwner,
        string memory name,
        string memory symbol,
        bool _isMintable,
        bool _isBurnable,
        bool _isPausable,
        bool _hasMaxSupply,
        uint256 _premintAmount,
        uint256 _maxSupply
    )
        BasicFeatureContract(
            initialOwner,
            name,
            symbol,
            _isMintable,
            _isBurnable,
            _isPausable,
            _hasMaxSupply,
            _premintAmount,
            _maxSupply
        )
    {}

    /// @notice Internal update function required by ERC20
    /// @dev Overrides both BasicFeatureContract and ERC20FlashMint
    function _update(address from, address to, uint256 value) internal override(ERC20, BasicFeatureContract) {
        super._update(from, to, value);
    }
}

// /// @title Feature Contract with Flash Mint and Permit Support
// /// @notice ERC20 token with both flash loan and permit functionality
// /// @dev Inherits from BasicFeatureContract and adds both ERC20FlashMint and ERC20Permit
contract FeatureFlashMintAndPermit is BasicFeatureContract, ERC20FlashMint, ERC20Permit {
    /// @notice Initializes token with both flash mint and permit functionality
    /// @param initialOwner Address that will own the contract
    /// @param name Token name
    /// @param symbol Token symbol
    /// @param _isMintable Whether tokens can be minted
    /// @param _isBurnable Whether tokens can be burned
    /// @param _isPausable Whether transfers can be paused
    /// @param _hasMaxSupply Whether max supply is enforced
    /// @param _premintAmount Initial supply to mint
    /// @param _maxSupply Maximum token supply if enabled
    constructor(
        address initialOwner,
        string memory name,
        string memory symbol,
        bool _isMintable,
        bool _isBurnable,
        bool _isPausable,
        bool _hasMaxSupply,
        uint256 _premintAmount,
        uint256 _maxSupply
    )
        BasicFeatureContract(
            initialOwner,
            name,
            symbol,
            _isMintable,
            _isBurnable,
            _isPausable,
            _hasMaxSupply,
            _premintAmount,
            _maxSupply
        )
        ERC20Permit(name)
    {}

    /// @notice Internal update function required by ERC20
    /// @dev Overrides BasicFeatureContract, ERC20FlashMint
    function _update(address from, address to, uint256 value) internal override(ERC20, BasicFeatureContract) {
        super._update(from, to, value);
    }
}
