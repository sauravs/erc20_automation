// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../src/BaseFactory.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {}
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract BaseFactoryTest is Test {
    BaseFactory public factory;
    MockERC20 public feeToken;
    address public owner;
    address public feeCollector;
    address public user;
    uint256 public deploymentFee = 1;

    event ContractDeployed(address contractAddress);

    function setUp() public {
        owner = makeAddr("owner");
        feeCollector = makeAddr("feeCollector");
        user = makeAddr("user");
        
        vm.startPrank(owner);                 //@audit : only owner can deploy the contract?
        feeToken = new MockERC20();
        factory = new BaseFactory(
            address(feeToken),
            deploymentFee,
            feeCollector
        );
        vm.stopPrank();

        // mint 100 tokens to user

        feeToken.mint(user, 100);

        // assert that user has 100 tokens

        assertEq(feeToken.balanceOf(user), 100);
    }

    function testConstructor() public {
        assertEq(address(factory.feeToken()), address(feeToken));
        assertEq(factory.deploymentFee(), deploymentFee);
        assertEq(factory.owner(), owner);
    }

    function testDeployContract() public {
      
        
        vm.startPrank(user);
        feeToken.approve(address(factory), deploymentFee);

        // vm.expectEmit(true, true, true, true);
        // emit ContractDeployed(address(0)); // actual address will be different

        factory.deployContract(
            user,
            "Test Token",
            "TEST",
            true,
            true,
            true,
            1000
        );
        vm.stopPrank();

        // Assertions
        assertEq(factory.getDeployedContracts().length, 1);
        assertEq(feeToken.balanceOf(feeCollector), deploymentFee);
    }

    // function testUpdateDeploymentFee() public {
    //     uint256 newFee = 200 ether;
    //     vm.prank(owner);
    //     factory.updateDeploymentFee(newFee);
    //     assertEq(factory.deploymentFee(), newFee);
    // }

    // function testUpdateFeeToken() public {
    //     address newToken = address(new MockERC20());
    //     vm.prank(owner);
    //     factory.updateFeeToken(IERC20(newToken));
    //     assertEq(address(factory.feeToken()), newToken);
    // }

    // function testUpdateFeeCollector() public {
    //     address newCollector = makeAddr("newCollector");
    //     vm.prank(owner);
    //     factory.updateFeeCollector(newCollector);
    //     assertEq(factory.feeCollector(), newCollector);
    // }

    // // Revert Tests

    // function testRevertWhenInsufficientAllowance() public {
    //     vm.startPrank(user);
    //     feeToken.approve(address(factory), DEPLOYMENT_FEE - 1);
        
    //     vm.expectRevert("ERC20: insufficient allowance");
    //     factory.deployContract(
    //         user,
    //         "Test Token",
    //         "TEST",
    //         true,
    //         true,
    //         true,
    //         1000 ether
    //     );
    //     vm.stopPrank();
    // }

    // function testRevertWhenInsufficientBalance() public {
    //     vm.startPrank(user);
    //     feeToken.approve(address(factory), DEPLOYMENT_FEE);
        
    //     vm.expectRevert("ERC20: transfer amount exceeds balance");
    //     factory.deployContract(
    //         user,
    //         "Test Token",
    //         "TEST",
    //         true,
    //         true,
    //         true,
    //         1000 ether
    //     );
    //     vm.stopPrank();
    // }

    // function testRevertWhenNonOwnerUpdatesDeploymentFee() public {
    //     vm.prank(user);
    //     vm.expectRevert("Ownable: caller is not the owner");
    //     factory.updateDeploymentFee(200 ether);
    // }

    // function testRevertWhenNonOwnerUpdatesFeeToken() public {
    //     vm.prank(user);
    //     vm.expectRevert("Ownable: caller is not the owner");
    //     factory.updateFeeToken(IERC20(address(0)));
    // }

    // function testRevertWhenNonOwnerUpdatesFeeCollector() public {
    //     vm.prank(user);
    //     vm.expectRevert("Ownable: caller is not the owner");
    //     factory.updateFeeCollector(address(0));
    // }

    // function testDeployedContractFeatures() public {
    //     feeToken.mint(user, DEPLOYMENT_FEE);
        
    //     vm.startPrank(user);
    //     feeToken.approve(address(factory), DEPLOYMENT_FEE);
        
    //     factory.deployContract(
    //         user,
    //         "Test Token",
    //         "TEST",
    //         true,
    //         true,
    //         true,
    //         1000 ether
    //     );
        
    //     address deployedAddr = factory.getDeployedContracts()[0];
    //     FeatureBasedContract deployedContract = FeatureBasedContract(deployedAddr);
        
    //     (bool isMintable, bool isBurnable, bool isPausable) = deployedContract.features();
    //     assertTrue(isMintable);
    //     assertTrue(isBurnable);
    //     assertTrue(isPausable);
    //     vm.stopPrank();
    // }
}