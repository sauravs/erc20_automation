// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../src/PermitFactory.sol";
import "../src/demo2.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {}
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract PermitFactoryTest is Test {
    
    PermitFactory public factory;
    FeaturePermit public permitToken;
    MockERC20 public feeToken;
    address public factoryOwner;
    address public feeCollector;
    address public user;
    address public user2;
    uint256 public deploymentFee = 2;



    address  public sender;                 // which will be used to sign the permit , he will not pay any gass fee
    address  public relayerAccount ;        // account which will pay the gas fee
    address  public receiver;               // account which is going to receive the tokens
    
    uint256 constant AMOUNT = 1000;
    //uint256 constant FEE = 10;

    uint256 constant SENDER_PRIVATE_KEY = 111;




    event ContractDeployed(address contractAddress);

    function setUp() public {
        
        factoryOwner = makeAddr("factoryOwner");
        user = makeAddr("user");
        user2 = makeAddr("user2");
        feeCollector = makeAddr("feeCollector");
       
        sender = vm.addr(SENDER_PRIVATE_KEY);
        relayerAccount = makeAddr("relayerAccount");
        receiver = makeAddr("receiver");

        vm.startPrank(factoryOwner);                 //@audit : only owner can deploy the contract?
        feeToken = new MockERC20();

        factory = new PermitFactory(                // to be deploy by web3tech
            address(feeToken),
            deploymentFee,
            feeCollector
        );

        vm.stopPrank();

        // mint 10000 fee tokens to sender

        feeToken.mint(sender, 10000);

        // assert that user has 10000 fee tokens

        assertEq(feeToken.balanceOf(sender), 10000);


        // deploy the permitToken Contract by any user(eg. sender)


        vm.startPrank(sender);
        feeToken.approve(address(factory), deploymentFee);
  
        vm.startPrank(sender);
        factory.deployContract(
            sender,
            "Test Token",
            "TEST",
            true,
            true,
            true,
            1000
        );

        address deployedAddr = factory.getDeployedContracts()[0];
        FeaturePermit permitToken = FeaturePermit(deployedAddr);

    }


     function testConstructor() public {

        assertEq(address(factory.feeToken()), address(feeToken));
        assertEq(factory.deploymentFee(), deploymentFee);
        assertEq(factory.owner(), factoryOwner);
    }


    function testDeployContract() public {

        
        vm.startPrank(sender);
        feeToken.approve(address(factory), deploymentFee);
  
        factory.deployContract(
            sender,
            "Test Token",
            "TEST",
            true,
            true,
            true,
            1000
        );

        vm.stopPrank();

        address deployedAddr = factory.getDeployedContracts()[0];
        FeaturePermit permitToken = FeaturePermit(deployedAddr);

        assertEq(permitToken.name(), "Test Token");
        assertEq(permitToken.symbol(), "TEST");
        assertEq(permitToken.totalSupply(), 1000);
        assertEq(permitToken.owner(), sender);

        // verify fee transfer  

        assertEq(feeToken.balanceOf(feeCollector), 2*(deploymentFee));  // since so far deployed two times once in the setup and once in this function

        assertEq(feeToken.balanceOf(sender), 10000 - 2*(deploymentFee));  // 10000 - 2*(deploymentFee) = 9996

    }


 function testPermitFunctionality() public {
        // Deploy token
        vm.startPrank(sender);
        feeToken.approve(address(factory), deploymentFee);
        
        vm.startPrank(sender);
        factory.deployContract(
            sender,
            "Test Token",
            "TEST",
            true,
            true,
            true,
            100000
        );
        
        address deployedAddr = factory.getDeployedContracts()[0];
        permitToken = FeaturePermit(deployedAddr);
        vm.stopPrank();

        // Setup permit parameters
        uint256 deadline = block.timestamp + 60;
        uint256 amount = 100;
        
        // Generate permit signature
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                permitToken.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256(
                            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                        ),
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
        vm.prank(relayerAccount);
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

    function _getPermitTypedDataHash(
        address owner,
        address spender,
        uint256 value,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                permitToken.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256(
                            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                        ),
                        owner,
                        spender,
                        value,
                        nonce,
                        deadline
                    )
                )
            )
        );
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