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
    address public user2;
    uint256 public deploymentFee = 2;

    event ContractDeployed(address contractAddress);

    function setUp() public {
        owner = makeAddr("owner");
        feeCollector = makeAddr("feeCollector");
        user = makeAddr("user");
        user2 = makeAddr("user2");
        
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
        assertEq(feeToken.balanceOf(user), 100 - deploymentFee);
    }

    function testUpdateDeploymentFee() public {
        uint256 newFee = 2;
        vm.prank(owner);
        factory.updateDeploymentFee(newFee);
        assertEq(factory.deploymentFee(), newFee);
    }

    function testUpdateFeeToken() public {
        address newToken = address(new MockERC20());
        vm.prank(owner);
        factory.updateFeeToken(IERC20(newToken));
        assertEq(address(factory.feeToken()), newToken);
    }

    function testUpdateFeeCollector() public {
        address newCollector = makeAddr("newCollector");
        vm.prank(owner);
        factory.updateFeeCollector(newCollector);
        assertEq(factory.feeCollector(), newCollector);
    }


      function testDeployedContractFeatures() public {

        vm.startPrank(user);
        feeToken.approve(address(factory), deploymentFee);
        
        factory.deployContract(
            user,
            "Test Token",
            "TEST",
            true,
            true,
            true,
            1000 
        );
        
        address deployedAddr = factory.getDeployedContracts()[0];
        FeatureBasedContract deployedContract = FeatureBasedContract(deployedAddr);
        
        (bool isMintable, bool isBurnable, bool isPausable) = deployedContract.features();
        assertTrue(isMintable);
        assertTrue(isBurnable);
        assertTrue(isPausable);
        vm.stopPrank();

        // Assertions
        assertEq(factory.getDeployedContracts().length, 1);
        assertEq(feeToken.balanceOf(feeCollector), deploymentFee);
        assertEq(feeToken.balanceOf(user), 100 - deploymentFee);

        // assert total supply is equal to premint amount

        assertEq(deployedContract.totalSupply(), 1000);

        // assert initial owner is user

        assertEq(deployedContract.owner(), user);


        // assert that preminted amount is transferred to user

        assertEq(deployedContract.balanceOf(user), 1000);

        // assert that user can transfer tokens to another address
        
        vm.prank(user);
        deployedContract.transfer(user2, 100);
        assertEq(deployedContract.balanceOf(user), 900);
        assertEq(deployedContract.balanceOf(user2), 100);




    }



    
    function testRevertWhenNonOwnerUpdatesDeploymentFee() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        factory.updateDeploymentFee(200);
    }


      function testRevertWhenNonOwnerUpdatesFeeToken() public {
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        factory.updateFeeToken(IERC20(address(0)));
    }

    function testRevertWhenNonOwnerUpdatesFeeCollector() public {
        vm.prank(user);
           vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        factory.updateFeeCollector(address(0));
    }

    // function testRevertWhenInsufficientAllowance() public {
    //     vm.startPrank(user);
    //     feeToken.approve(address(factory), deploymentFee - 1);

    //     // vm.expectPartialRevert(feeToken.ERC20InsufficientAllowance.selector);

    //     vm.expectRevert(abi.encodeWithSelector(ERC20.ERC20InsufficientAllowance.selector, user ,deploymentFee,  deploymentFee - 1));
        
    // //    vm.expectRevert(abi.encodeWithSelector(ERC20.ERC20InsufficientAllowance.selector, user ,deploymentFee,  deploymentFee - 1));

       

    //    //ERC20InsufficientAllowance(spender, currentAllowance, value);
    //    //error OwnableUnauthorizedAccount(address account);
        
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
    //     feeToken.approve(address(factory), deploymentFee);
        
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


}