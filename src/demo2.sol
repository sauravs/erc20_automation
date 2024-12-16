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

contract FeatureFlashMint is FeatureBasedContract, ERC20FlashMint {
    constructor(
        address initialOwner,
        string memory name,
        string memory symbol,
        bool _isMintable,
        bool _isBurnable,
        bool _isPausable,
        uint256 _premintAmount
    )
        FeatureBasedContract(
            initialOwner,
            name,
            symbol,
            _isMintable,
            _isBurnable,
            _isPausable,
            _premintAmount
        )
    {}

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, FeatureBasedContract) {
        super._update(from, to, value);
    }
}

contract FeaturePermit is FeatureBasedContract, ERC20Permit {
    constructor(
        address initialOwner,
        string memory name,
        string memory symbol,
        bool _isMintable,
        bool _isBurnable,
        bool _isPausable,
        uint256 _premintAmount
    )
        FeatureBasedContract(
            initialOwner,
            name,
            symbol,
            _isMintable,
            _isBurnable,
            _isPausable,
            _premintAmount
        )
        ERC20Permit(name)
    {}

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, FeatureBasedContract) {
        super._update(from, to, value);
    }
}

contract FeatureFlashMintAndPermit is
    FeatureBasedContract,
    ERC20FlashMint,
    ERC20Permit
{
    constructor(
        address initialOwner,
        string memory name,
        string memory symbol,
        bool _isMintable,
        bool _isBurnable,
        bool _isPausable,
        uint256 _premintAmount
    )
        FeatureBasedContract(
            initialOwner,
            name,
            symbol,
            _isMintable,
            _isBurnable,
            _isPausable,
            _premintAmount
        )
        ERC20Permit(name)
    {}

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, FeatureBasedContract) {
        super._update(from, to, value);
    }
}
