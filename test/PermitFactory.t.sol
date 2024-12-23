// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import "../src/PermitFactory.sol";
import {BasicFeatureContract} from "../src/CodeSnippet.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("MockFeetoken", "MTK") {
        _mint(msg.sender, 1000);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract PermitFactoryTest is Test {
    PermitFactory public factory;
    FeaturePermit public permitToken;
    MockERC20 public feetoken;
    address public owner;
    address public user;
    address public feeCollector;
    uint256 public constant DEPLOYMENT_FEE = 1;

    address public sender; // which will be used to sign the permit , he will not pay any gass fee
    address public relayerAccount; // account which will pay the gas fee
    address public receiver; // account which is going to receive the tokens

    uint256 constant AMOUNT = 1000;
    uint256 constant SENDER_PRIVATE_KEY = 111;

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        feeCollector = makeAddr("feeCollector");
        receiver = makeAddr("receiver");
        relayerAccount = makeAddr("relayerAccount");
        sender = vm.addr(SENDER_PRIVATE_KEY);

        vm.startPrank(owner);
        feetoken = new MockERC20();
        factory = new PermitFactory(address(feetoken), DEPLOYMENT_FEE, feeCollector);
        vm.stopPrank();

        // verify owner has 1000 fee tokens

        assertEq(feetoken.balanceOf(owner), 1000);

        // fund user with some feetoken

        vm.prank(owner);
        feetoken.transfer(user, 100);
        assertEq(feetoken.balanceOf(user), 100);

        // mint 10000 fee tokens to sender

        feetoken.mint(sender, 10000);

        // assert that sender has 10000 fee tokens

        assertEq(feetoken.balanceOf(sender), 10000);

        // deploy the permitToken Contract by any user(eg. sender)

        vm.prank(sender);
        feetoken.approve(address(factory), DEPLOYMENT_FEE);

        vm.prank(sender);
        factory.deployContract(sender, "Test Token", "TEST", true, true, true, true, 1000, 10000);

        address deployedAddr = factory.getDeployedContracts()[0];
        FeaturePermit permitToken = FeaturePermit(deployedAddr);
    }

    function testConstructorValidations() public {
        vm.expectRevert(PermitFactory.InvalidAddress.selector);
        new PermitFactory(address(0), DEPLOYMENT_FEE, feeCollector);

        vm.expectRevert(PermitFactory.InvalidAddress.selector);
        new PermitFactory(address(feetoken), DEPLOYMENT_FEE, address(0));
    }

    function testDeployContract() public {
        vm.startPrank(user);
        feetoken.approve(address(factory), DEPLOYMENT_FEE);

        address deployedAddr = factory.deployContract(user, "Test Token", "TEST", true, true, true, true, 100, 10000);

        FeaturePermit token = FeaturePermit(deployedAddr);

        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TEST");
        assertEq(token.owner(), user);
        assertEq(feetoken.balanceOf(feeCollector), 2 * (DEPLOYMENT_FEE)); //since deployed two times
        assertEq(feetoken.balanceOf(user), 100 - DEPLOYMENT_FEE);
        assertEq(token.totalSupply(), 100);
        assertEq(token.maxSupply(), 10000);

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
        feetoken.approve(address(factory), DEPLOYMENT_FEE);

        vm.expectRevert(PermitFactory.MaxSupplyTooLow.selector);
        factory.deployContract(user, "Test token", "TEST", true, true, true, true, 0, 0);
        vm.stopPrank();
    }

    function testRevertOnInitialSupplyExceedsMax() public {
        vm.startPrank(user);
        feetoken.approve(address(factory), DEPLOYMENT_FEE);

        vm.expectRevert(PermitFactory.InitialSupplyExceedsMax.selector);
        factory.deployContract(user, "Test token", "TEST", true, true, true, true, 1000, 100);
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

    function testUpdateFeetoken() public {
        address newtoken = address(new MockERC20());
        vm.prank(owner);
        factory.updateFeeToken(IERC20(newtoken));
        assertEq(address(factory.feeToken()), newtoken);
    }

    function testRevertUpdateFeetokenZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(PermitFactory.InvalidAddress.selector);
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
        vm.expectRevert(PermitFactory.InvalidAddress.selector);
        factory.updateFeeCollector(address(0));
    }

    function testGetDeployedContracts() public {
        vm.startPrank(user);
        feetoken.approve(address(factory), DEPLOYMENT_FEE * 2);

        address token1 = factory.deployContract(user, "token1", "TK1", true, true, true, true, 100, 1000);

        address token2 = factory.deployContract(user, "token2", "TK2", true, true, true, true, 100, 1000);

        address[] memory deployedtokens = factory.getDeployedContracts();
        assertEq(deployedtokens.length, 3); // +1 from setup
        assertEq(deployedtokens[1], token1);
        assertEq(deployedtokens[2], token2);
        vm.stopPrank();
    }

    function testPermitFunctionality() public {
        // Deploy token
        vm.startPrank(sender);
        feetoken.approve(address(factory), DEPLOYMENT_FEE);

        factory.deployContract(sender, "Test Token", "TEST", true, true, true, true, 1000, 10000);

        address deployedAddr = factory.getDeployedContracts()[0];
        permitToken = FeaturePermit(deployedAddr);
        vm.stopPrank();

        // Setup permit parameters
        address spender = makeAddr("spender");
        uint256 deadline = block.timestamp + 60;
        uint256 amount = 100;

        // Generate permit signature
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                permitToken.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        sender,
                        relayerAccount,
                        amount,
                        permitToken.nonces(sender),
                        deadline
                    )
                )
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SENDER_PRIVATE_KEY, digest);

        // execute permit
        vm.prank(sender);
        permitToken.permit(sender, relayerAccount, amount, deadline, v, r, s);

        // verify permit
        assertEq(permitToken.allowance(sender, relayerAccount), amount);
        assertEq(permitToken.nonces(sender), 1);

        // check balance of sender before exeuting transfer from sender to receiver via relayer

        //console.log(permitToken.balanceOf(sender));  // 1000

        // test transfer
        vm.prank(relayerAccount);
        permitToken.transferFrom(sender, receiver, amount);

        // verify balances
        assertEq(permitToken.balanceOf(receiver), amount);
        assertEq(permitToken.balanceOf(sender), 1000 - amount);
    }
}
