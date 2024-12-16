// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/BaseFactory.sol";
import "../src/demo2.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BaseFactoryTest is Test {
    BaseFactory factory;
    ERC20 paymentToken;

    address owner = address(0x123);
    address initialOwner = address(0x456);
    string name = "TestToken";
    string symbol = "TTK";
    bool isMintable = true;
    bool isBurnable = true;
    bool isPausable = true;
    uint256 premintAmount = 1000;
    uint256 paymentAmount = 100;

    function setUp() public {
        paymentToken = new ERC20("PaymentToken", "PTK");
        factory = new BaseFactory(address(paymentToken));
    }

    function testConstructor() public {
        assertEq(address(factory.paymentToken()), address(paymentToken));
    }

    function testDeployContract() public {
        // Mint tokens to the test contract to simulate payment
        paymentToken._mint(address(this), paymentAmount);
        paymentToken.approve(address(factory), paymentAmount);

        factory.DeployContract(
            initialOwner,
            name,
            symbol,
            isMintable,
            isBurnable,
            isPausable,
            premintAmount,
            paymentAmount
        );

        address deployedContract = factory.deployedContracts(0);
        assertTrue(deployedContract != address(0));
    }

    function testDeployContractRevert() public {
        // No tokens minted to the test contract, so transfer should fail
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        factory.DeployContract(
            initialOwner,
            name,
            symbol,
            isMintable,
            isBurnable,
            isPausable,
            premintAmount,
            paymentAmount
        );
    }

    function testDeployContractWithZeroAddressRevert() public {
        // Mint tokens to the test contract to simulate payment
        paymentToken._mint(address(this), paymentAmount);
        paymentToken.approve(address(factory), paymentAmount);

        vm.expectRevert("Ownable: new owner is the zero address");
        factory.DeployContract(
            address(0),
            name,
            symbol,
            isMintable,
            isBurnable,
            isPausable,
            premintAmount,
            paymentAmount
        );
    }
}