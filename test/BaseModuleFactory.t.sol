// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../src/BasicModuleFactory.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockFeeToken", "MTK") {
        _mint(msg.sender, 1000);
    }
}

contract BasicModuleFactoryTest is Test {
    BasicModuleFactory public factory;
    MockERC20 public feeToken;
    address public owner;
    address public user;
    address public feeCollector;
    uint256 public constant DEPLOYMENT_FEE = 1;

    event ContractDeployed(address indexed contractAddress);

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        feeCollector = makeAddr("feeCollector");

        vm.startPrank(owner);
        feeToken = new MockERC20();
        factory = new BasicModuleFactory(
            address(feeToken),
            DEPLOYMENT_FEE,
            feeCollector
        );
        vm.stopPrank();

     
         // verify owner has 1000 fee tokens
        
        assertEq(feeToken.balanceOf(owner), 1000);

        // fund user with some feetoken

        vm.prank(owner);
        feeToken.transfer(user, 100);
        assertEq(feeToken.balanceOf(user), 100);

    }

    function testConstructorValidations() public {
        vm.expectRevert(BasicModuleFactory.InvalidAddress.selector);
        new BasicModuleFactory(
            address(0),
            DEPLOYMENT_FEE,
            feeCollector
        );

        vm.expectRevert(BasicModuleFactory.InvalidAddress.selector);
        new BasicModuleFactory(
            address(feeToken),
            DEPLOYMENT_FEE,
            address(0)
        );
    }

    function testDeployContract() public {
        vm.startPrank(user);
        feeToken.approve(address(factory), DEPLOYMENT_FEE);


        address deployedAddr = factory.deployContract(
            user,
            "Test Token",
            "TEST",
            true,
            true,
            true,
            true,
            100 ,                        
            10000
        );

        BasicFeatureContract token = BasicFeatureContract(deployedAddr);
        
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TEST");
        assertEq(token.owner(), user);
        assertEq(feeToken.balanceOf(feeCollector), DEPLOYMENT_FEE);
        assertEq(feeToken.balanceOf(user), 100 - DEPLOYMENT_FEE);
        assertEq(token.totalSupply(), 100);
        assertEq(token.maxSupply(), 10000);
   
        
    BasicFeatureContract.Features memory features = token.getFeatures();
    assertEq(features.isMintable, true);
    assertEq(features.isBurnable, true); 
    assertEq(features.isPausable, true);
    assertEq(features.hasMaxSupply, true);


        vm.stopPrank();

       // testing token related feature after new token is deployed

       // test mint new token

       vm.prank(user);
       token.mint(user, 100);
       assertEq(token.totalSupply(), 200);

        // test burn token

        vm.prank(user);
        token.burn(100);
        assertEq(token.totalSupply(), 100);

        // test pause token

        vm.prank(user);
        token.pause();
        assertEq(token.paused(), true);

        // test unpause token
        vm.prank(user);
        token.unpause();
        assertEq(token.paused(), false);


        // test mint token with max supply
        vm.prank(user);
        token.mint(user, 9900);
        assertEq(token.totalSupply(), 10000);


        // test mint token with max supply exceeded
        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(BasicFeatureContract.MaxSupplyExceeded.selector, 10100, 10000));
        token.mint(user, 100);

       // test transfer ownership

         vm.prank(user);
        token.transferOwnership(owner);
        assertEq(token.owner(), owner);

        // test renounce ownership

        vm.prank(owner);
        token.renounceOwnership();
        assertEq(token.owner(), address(0));


        // test transfer function

        vm.prank(user);
        token.transfer(owner, 100);
        assertEq(token.balanceOf(owner), 100);


    }

    function testRevertOnMaxSupplyZero() public {
        vm.startPrank(user);
        feeToken.approve(address(factory), DEPLOYMENT_FEE);

        vm.expectRevert(BasicModuleFactory.MaxSupplyTooLow.selector);
        factory.deployContract(
            user,
            "Test Token",
            "TEST",
            true,
            true,
            true,
            true,
            0,
            0
        );
        vm.stopPrank();
    }

    function testRevertOnInitialSupplyExceedsMax() public {
        vm.startPrank(user);
        feeToken.approve(address(factory), DEPLOYMENT_FEE);

        vm.expectRevert(BasicModuleFactory.InitialSupplyExceedsMax.selector);
        factory.deployContract(
            user,
            "Test Token",
            "TEST",
            true,
            true,
            true,
            true,
            1000 ,
            100 
        );
        vm.stopPrank();
    }

    

    function testUpdateDeploymentFee() public {
        uint256 newFee = 2 ether;
        vm.prank(owner);
        factory.updateDeploymentFee(newFee);
        assertEq(factory.deploymentFee(), newFee);
    }

    function testRevertUnauthorizedFeeUpdate() public {
        vm.prank(user);
       vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        factory.updateDeploymentFee(2 ether);
    }

    function testUpdateFeeToken() public {
        address newToken = address(new MockERC20());
        vm.prank(owner);
        factory.updateFeeToken(IERC20(newToken));
        assertEq(address(factory.feeToken()), newToken);
    }

    function testRevertUpdateFeeTokenZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(BasicModuleFactory.InvalidAddress.selector);
        factory.updateFeeToken(IERC20(address(0)));
    }

    function testUpdateFeeCollector() public {
        address newCollector = makeAddr("newCollector");
        vm.prank(owner);
        factory.updateFeeCollector(newCollector);
        assertEq(factory.feeCollector(), newCollector);
    }

    function testRevertUpdateFeeCollectorZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(BasicModuleFactory.InvalidAddress.selector);
        factory.updateFeeCollector(address(0));
    }

    function testGetDeployedContracts() public {
        vm.startPrank(user);
        feeToken.approve(address(factory), DEPLOYMENT_FEE * 2);

        address token1 = factory.deployContract(
            user,
            "Token1",
            "TK1",
            true,
            true,
            true,
            true,
            100 ,
            1000 
        );

        address token2 = factory.deployContract(
            user,
            "Token2",
            "TK2",
            true,
            true,
            true,
            true,
            100,
            1000 
        );

        address[] memory deployedTokens = factory.getDeployedContracts();
        assertEq(deployedTokens.length, 2);
        assertEq(deployedTokens[0], token1);
        assertEq(deployedTokens[1], token2);
        vm.stopPrank();
    }
}