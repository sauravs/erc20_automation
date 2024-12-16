// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "forge-std/Test.sol";
// import "../src/FlashmintFactory.sol";
// import "../src/demo2.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contract FlashmintFactoryTest is Test {
//     FlashmintFactory factory;
//     IERC20 paymentToken;

//     address owner = address(0x123);
//     address initialOwner = address(0x456);
//     string name = "TestToken";
//     string symbol = "TTK";
//     bool isMintable = true;
//     bool isBurnable = true;
//     bool isPausable = true;
//     uint256 premintAmount = 1000;
//     uint256 paymentAmount = 100;

//     function setUp() public {
//         paymentToken = IERC20(address(new ERC20("PaymentToken", "PTK")));
//         factory = new FlashmintFactory(address(paymentToken));
//     }

//     function testConstructor() public {
//         assertEq(address(factory.paymentToken()), address(paymentToken));
//     }

//     function testDeployContract() public {
//         factory.DeployContract(
//             initialOwner,
//             name,
//             symbol,
//             isMintable,
//             isBurnable,
//             isPausable,
//             premintAmount,
//             paymentAmount
//         );

//         address deployedContract = factory.deployedContracts(0);
//         assertTrue(deployedContract != address(0));
//     }

//     function testDeployContractRevert() public {
//         vm.expectRevert();
//         factory.DeployContract(
//             address(0),
//             name,
//             symbol,
//             isMintable,
//             isBurnable,
//             isPausable,
//             premintAmount,
//             paymentAmount
//         );
//     }
// }