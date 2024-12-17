// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../src/FlashMintFactory.sol";
import "../src/demo2.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {}
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}


contract MockFlashBorrower is IERC3156FlashBorrower {
    bool public shouldRepay;
    
    constructor(bool _shouldRepay) {
        shouldRepay = _shouldRepay;
    }
    
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        if (shouldRepay) {
            IERC20(token).approve(msg.sender, amount + fee);
            return keccak256("ERC3156FlashBorrower.onFlashLoan");
        }
        return bytes32(0);
    }
}

contract FlashMintFactoryTest is Test {
    
    FlashMintFactory public factory;
    MockERC20 public feeToken;
    address public owner;
    address public user;
    address public feeCollector;
    uint256 public constant DEPLOYMENT_FEE = 1;
    
    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        feeCollector = makeAddr("feeCollector");
        
        vm.startPrank(owner);
        feeToken = new MockERC20();
        factory = new FlashMintFactory(
            address(feeToken),
            DEPLOYMENT_FEE,
            feeCollector
        );
        vm.stopPrank();

        vm.prank(owner);
        feeToken.mint(user, 10000);
    }

    function testFlashLoan() public {
        // Deploy flash mint token
        vm.startPrank(user);
        feeToken.approve(address(factory), DEPLOYMENT_FEE);
        
        factory.deployContract(
            user,
            "Flash Token",
            "FLASH",
            true,
            true,
            true,
            100000
        );
        
        address deployedAddr = factory.getDeployedContracts()[0];
        FeatureFlashMint flashToken = FeatureFlashMint(deployedAddr);
        vm.stopPrank();

        // Setup flash borrower
        MockFlashBorrower goodBorrower = new MockFlashBorrower(true);
        uint256 loanAmount = 100;

        // Execute flash loan
        vm.prank(address(goodBorrower));
        flashToken.flashLoan(
            IERC3156FlashBorrower(address(goodBorrower)),
            address(flashToken),
            loanAmount,
            ""
        );
    }


    function testMaxFlashLoan() public {
        vm.startPrank(user);
        feeToken.approve(address(factory), DEPLOYMENT_FEE);
        
        factory.deployContract(
            user,
            "Flash Token",
            "FLASH",
            true,
            true,
            true,
            1000 ether
        );
        
        address deployedAddr = factory.getDeployedContracts()[0];
        FeatureFlashMint flashToken = FeatureFlashMint(deployedAddr);
        
        uint256 maxLoan = flashToken.maxFlashLoan(address(flashToken));
        assertEq(maxLoan, type(uint256).max - flashToken.totalSupply());  // in default case should be maximum value - total supply(in circulation)
        vm.stopPrank();
    }

    function testFlashFee() public {
        vm.startPrank(user);
        feeToken.approve(address(factory), DEPLOYMENT_FEE);
        
        factory.deployContract(
            user,
            "Flash Token",
            "FLASH",
            true,
            true,
            true,
            1000
        );
        
        address deployedAddr = factory.getDeployedContracts()[0];
        FeatureFlashMint flashToken = FeatureFlashMint(deployedAddr);
        
        uint256 fee = flashToken.flashFee(address(flashToken), 1); // value doesn't matter?but why?
        assertEq(fee, 0); // default implementation has zero fees
        vm.stopPrank();
    }


       function testRevertWhenNonOwnerUpdatesDeploymentFee() public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        factory.updateDeploymentFee(200);
        vm.stopPrank();
    }


      function testRevertWhenNonOwnerUpdatesFeeToken() public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        factory.updateFeeToken(IERC20(address(0)));
        vm.stopPrank();
    }

    function testRevertWhenNonOwnerUpdatesFeeCollector() public {
        vm.startPrank(user);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user));
        factory.updateFeeCollector(address(0));
        vm.stopPrank();
    }


}