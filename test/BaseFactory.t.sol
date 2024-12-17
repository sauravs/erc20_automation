// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.22;

// import "forge-std/Test.sol";
// import "../src/BaseFactory.sol";
// import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// contract MockERC20 is ERC20 {
//     constructor() ERC20("Mock Token", "MTK") {}
//     function mint(address to, uint256 amount) public {
//         _mint(to, amount);
//     }
// }

// contract BaseFactoryTest is Test {
//     BaseFactory public factory;
//     MockERC20 public feeToken;
//     address public owner;
//     address public feeCollector;
//     address public user;
//     address public user2;
//     uint256 public deploymentFee = 2;

//     event ContractDeployed(address contractAddress);

//     function setUp() public {
//         owner = makeAddr("owner");
//         feeCollector = makeAddr("feeCollector");
//         user = makeAddr("user");
//         user2 = makeAddr("user2");
        
//         vm.startPrank(owner);                 //@audit : only owner can deploy the contract?
//         feeToken = new MockERC20();
//         factory = new BaseFactory(           // to be deploy by web3tech
//             address(feeToken),
//             deploymentFee,
//             feeCollector
//         );
//         vm.stopPrank();

//         // mint 100 tokens to user

//         feeToken.mint(user, 100);

//         // assert that user has 100 tokens

//         assertEq(feeToken.balanceOf(user), 100);
//     }

//     function testConstructor() public {
//         assertEq(address(factory.feeToken()), address(feeToken));
//         assertEq(factory.deploymentFee(), deploymentFee);
//         assertEq(factory.owner(), owner);
//     }

//     function testDeployContract() public {
      
        
//         vm.startPrank(user);
//         feeToken.approve(address(factory), deploymentFee);

//         // vm.expectEmit(true, true, true, true);
//         // emit ContractDeployed(address(0)); // actual address will be different

//         factory.deployContract(                  //deploy by user
//             user,
//             "Test Token",
//             "TEST",
//             true,
//             true,
//             true,
//             1000
//         );
//         vm.stopPrank();

//         // Assertions
//         assertEq(factory.getDeployedContracts().length, 1);
//         assertEq(feeToken.balanceOf(feeCollector), deploymentFee);
//         assertEq(feeToken.balanceOf(user), 100 - deploymentFee);
//     }

//     function testUpdateDeploymentFee() public {
//         uint256 newFee = 2;
//         vm.prank(owner);
//         factory.updateDeploymentFee(newFee);
//         assertEq(factory.deploymentFee(), newFee);
//     }

//     function testUpdateFeeToken() public {
//         address newToken = address(new MockERC20());
//         vm.prank(owner);
//         factory.updateFeeToken(IERC20(newToken));
//         assertEq(address(factory.feeToken()), newToken);
//     }

//     function testUpdateFeeCollector() public {
//         address newCollector = makeAddr("newCollector");
//         vm.prank(owner);
//         factory.updateFeeCollector(newCollector);
//         assertEq(factory.feeCollector(), newCollector);
//     }


//       function testDeployedContractFeatures() public {

//         vm.startPrank(user);
//         feeToken.approve(address(factory), deploymentFee);
        
//         factory.deployContract(
//             user,
//             "Test Token",
//             "TEST",
//             true,
//             true,
//             true,
//             1000 
//         );
        
//         address deployedAddr = factory.getDeployedContracts()[0];
//         FeatureBasedContract deployedContract = FeatureBasedContract(deployedAddr);
        
//         (bool isMintable, bool isBurnable, bool isPausable) = deployedContract.features();
//         assertTrue(isMintable);
//         assertTrue(isBurnable);
//         assertTrue(isPausable);
//         vm.stopPrank();

//         // Assertions
//         assertEq(factory.getDeployedContracts().length, 1);
//         assertEq(feeToken.balanceOf(feeCollector), deploymentFee);
//         assertEq(feeToken.balanceOf(user), 100 - deploymentFee);

//         // assert total supply is equal to premint amount

//         assertEq(deployedContract.totalSupply(), 1000);

//         // assert initial owner is user

//         assertEq(deployedContract.owner(), user);


//         // assert that preminted amount is transferred to user

//         assertEq(deployedContract.balanceOf(user), 1000);

//         // assert that user can transfer tokens to another address
        
//         vm.prank(user);
//         deployedContract.transfer(user2, 100);
//         assertEq(deployedContract.balanceOf(user), 900);
//         assertEq(deployedContract.balanceOf(user2), 100);

//         // assert that user can approve another address to spend tokens on their behalf
        
//         vm.prank(user);
//         deployedContract.approve(user2, 100);
//         assertEq(deployedContract.allowance(user, user2), 100);

//         // assert that user2 can transfer tokens on behalf of user
        
//         vm.prank(user2);
//         deployedContract.transferFrom(user, user2, 100);
//         assertEq(deployedContract.balanceOf(user), 800);


//         // assert that owner (user) can mint tokens
           
//         vm.prank(user);
//         deployedContract.mint(user, 100);

//         // assert totalsupply is increased by 100

//         assertEq(deployedContract.totalSupply(), 1100);

//         // assert user balance is increased by 100

//         assertEq(deployedContract.balanceOf(user), 900);


//         // assert transaction is reverted when non-owner tries to mint tokens   

//         vm.prank(user2);
//         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user2));
//         deployedContract.mint(user2, 100);

//         // assert that owner (user) can burn tokens

//         vm.prank(user);
//         deployedContract.burn(100);                   // @audit from which wallet it is burning? why owner wallet? does it make sense?

//         // assert totalsupply is decreased by 100

//         assertEq(deployedContract.totalSupply(), 1000);

//         // assert user balance is decreased by 100

//         assertEq(deployedContract.balanceOf(user), 800);


//         // assert transaction is reverted when non-owner tries to burn tokens

//         // vm.prank(user2);
//         // vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user2));
//         // deployedContract.burn(100);


//         // assert that owner (user) can pause the contract

//         vm.prank(user);

//         deployedContract.pause();

//         // assert that contract is paused

//         assertTrue(deployedContract.paused());

//         // assert transaction is reverted when non-owner tries to pause the contract

//         vm.prank(user2);
//         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user2));
//         deployedContract.pause();

      
//         // assert that owner (user) can unpause the contract

//         vm.prank(user);

//         deployedContract.unpause();

//         // assert that contract is unpaused

//         assertFalse(deployedContract.paused());


//         // assert transaction is reverted when non-owner tries to unpause the contract

//         vm.prank(user2);

//         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user2));

//         deployedContract.unpause();


//         // assert that owner (user) can transfer ownership

//         vm.prank(user);

//         deployedContract.transferOwnership(user2);

//         // assert that owner is now user2

//         assertEq(deployedContract.owner(), user2);


//         // assert transaction is reverted when non-owner tries to transfer ownership

//         // vm.prank(user2);

//         // vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user2));

//         // deployedContract.transferOwnership(user);


//         // pause the contract by the owner then try to mint tokens , it should revert


//         // vm.prank(user2);

//         // deployedContract.pause();

//         // vm.expectRevert("Pausable: paused");

//         // deployedContract.mint(user, 100);
        



//     }


//     function testRevertWhenNonOwnerUpdatesDeploymentFee() public {
//         vm.prank(user);
//         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
//         factory.updateDeploymentFee(200);
//     }


//       function testRevertWhenNonOwnerUpdatesFeeToken() public {
//         vm.prank(user);
//         vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
//         factory.updateFeeToken(IERC20(address(0)));
//     }

//     function testRevertWhenNonOwnerUpdatesFeeCollector() public {
//         vm.prank(user);
//            vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
//         factory.updateFeeCollector(address(0));
//     }



// }