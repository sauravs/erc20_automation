// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import "../src/FlashMintFactory.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000 ether);
    }
}

contract MockFlashBorrower is IERC3156FlashBorrower {
    bool public willRepay;
    address public token;
    uint256 public amount;
    uint256 public fee;

    constructor(bool _willRepay) {
        willRepay = _willRepay;
    }

    function onFlashLoan(address initiator, address _token, uint256 _amount, uint256 _fee, bytes calldata)
        external
        returns (bytes32)
    {
        token = _token;
        amount = _amount;
        fee = _fee;

        if (willRepay) {
            IERC20(_token).approve(msg.sender, _amount + _fee);
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
    uint256 public constant DEPLOYMENT_FEE = 1 ether;

    event ContractDeployed(address indexed contractAddress);

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        feeCollector = makeAddr("feeCollector");

        vm.startPrank(owner);
        feeToken = new MockERC20();
        factory = new FlashMintFactory(address(feeToken), DEPLOYMENT_FEE, feeCollector);

        // Transfer fee tokens to user
        feeToken.transfer(user, 10 ether);
        vm.stopPrank();
    }

    function testFlashLoan() public {
        vm.startPrank(user);
        feeToken.approve(address(factory), DEPLOYMENT_FEE);

        address deployedAddr =
            factory.deployContract(user, "Flash Token", "FLASH", true, true, true, true, 1000 ether, 10000 ether);

        FeatureFlashMint flashToken = FeatureFlashMint(deployedAddr);

        // Create borrower that will repay
        MockFlashBorrower goodBorrower = new MockFlashBorrower(true);
        uint256 loanAmount = 100 ether;

        // Execute flash loan
        bool success =
            flashToken.flashLoan(IERC3156FlashBorrower(address(goodBorrower)), address(flashToken), loanAmount, "");

        assertTrue(success);
        assertEq(goodBorrower.token(), address(flashToken));
        assertEq(goodBorrower.amount(), loanAmount);
        assertEq(goodBorrower.fee(), 0);
        vm.stopPrank();
    }

    function testFailedFlashLoan() public {
        vm.startPrank(user);
        feeToken.approve(address(factory), DEPLOYMENT_FEE);

        address deployedAddr =
            factory.deployContract(user, "Flash Token", "FLASH", true, true, true, true, 1000 ether, 10000 ether);

        FeatureFlashMint flashToken = FeatureFlashMint(deployedAddr);

        // Create borrower that won't repay
        MockFlashBorrower badBorrower = new MockFlashBorrower(false);
        uint256 loanAmount = 100 ether;

        vm.expectRevert("ERC3156: invalid flashLoan callback");
        flashToken.flashLoan(IERC3156FlashBorrower(address(badBorrower)), address(flashToken), loanAmount, "");
        vm.stopPrank();
    }

    function testFlashFee() public {
        vm.startPrank(user);
        feeToken.approve(address(factory), DEPLOYMENT_FEE);

        address deployedAddr =
            factory.deployContract(user, "Flash Token", "FLASH", true, true, true, true, 1000 ether, 10000 ether);

        FeatureFlashMint flashToken = FeatureFlashMint(deployedAddr);

        // Test valid token
        uint256 fee = flashToken.flashFee(address(flashToken), 100 ether);
        assertEq(fee, 0); // default implementation has zero fees

        vm.stopPrank();
    }

    function testMaxFlashLoan() public {
        vm.startPrank(user);
        feeToken.approve(address(factory), DEPLOYMENT_FEE);

        address deployedAddr =
            factory.deployContract(user, "Flash Token", "FLASH", true, true, true, true, 1000 ether, 10000 ether);

        FeatureFlashMint flashToken = FeatureFlashMint(deployedAddr);

        // Test valid token
        uint256 maxLoan = flashToken.maxFlashLoan(address(flashToken));
        assertEq(maxLoan, type(uint256).max - flashToken.totalSupply());

        // Test invalid token
        assertEq(flashToken.maxFlashLoan(address(0x1)), 0);
        vm.stopPrank();
    }
}
