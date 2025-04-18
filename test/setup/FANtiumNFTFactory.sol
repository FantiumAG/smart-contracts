// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import { IERC20MetadataUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { FANtiumNFTV8 } from "src/FANtiumNFTV8.sol";
import { Collection, CollectionData } from "src/interfaces/IFANtiumNFT.sol";
import { UnsafeUpgrades } from "src/upgrades/UnsafeUpgrades.sol";
import { BaseTest } from "test/BaseTest.sol";
import { FANtiumUserManagerFactory } from "test/setup/FANtiumUserManagerFactory.sol";

/**
 * @notice Collection data structure for deserialization.
 * We cannot use the Collection struct because Foundry requires fields of the struct to be in alphabetical order.
 */
struct CollectionJson {
    address payable athleteAddress;
    uint256 athletePrimarySalesBPS;
    uint256 athleteSecondarySalesBPS;
    bool exists;
    address payable fantiumSalesAddress;
    uint256 fantiumSecondarySalesBPS;
    uint24 invocations;
    bool isMintable;
    bool isPaused;
    uint256 launchTimestamp;
    uint256 maxInvocations;
    uint256 otherEarningShare1e7;
    uint256 price;
    uint256 tournamentEarningShare1e7;
}

contract FANtiumNFTFactory is BaseTest, FANtiumUserManagerFactory {
    using ECDSA for bytes32;

    address public fantiumNFT_admin = makeAddr("admin");
    address public fantiumNFT_trustedForwarder = makeAddr("trustedForwarder");
    address payable public fantiumNFT_athlete = payable(makeAddr("athlete"));
    address payable public fantiumNFT_treasuryPrimary = payable(makeAddr("treasuryPrimary"));
    address payable public fantiumNFT_treasurySecondary = payable(makeAddr("treasurySecondary"));
    address public fantiumNFT_tokenUpgrader = makeAddr("tokenUpgrader");
    address public fantiumNFT_signer;
    uint256 public fantiumNFT_signerKey;

    ERC20 public usdc;
    address public fantiumNFT_implementation;
    address public fantiumNFT_proxy;
    FANtiumNFTV8 public fantiumNFT;

    function setUp() public virtual override {
        (fantiumNFT_signer, fantiumNFT_signerKey) = makeAddrAndKey("rewarder");
        FANtiumUserManagerFactory.setUp();

        usdc = new ERC20("USD Coin", "USDC");
        fantiumNFT_implementation = address(new FANtiumNFTV8());
        fantiumNFT_proxy = UnsafeUpgrades.deployUUPSProxy(
            fantiumNFT_implementation, abi.encodeCall(FANtiumNFTV8.initialize, (fantiumNFT_admin))
        );
        fantiumNFT = FANtiumNFTV8(fantiumNFT_proxy);

        // Configure roles
        vm.startPrank(fantiumNFT_admin);
        fantiumNFT.grantRole(fantiumNFT.FORWARDER_ROLE(), fantiumNFT_trustedForwarder);
        fantiumNFT.grantRole(fantiumNFT.SIGNER_ROLE(), fantiumNFT_signer);
        fantiumNFT.grantRole(fantiumNFT.TOKEN_UPGRADER_ROLE(), fantiumNFT_tokenUpgrader);
        fantiumNFT.setERC20PaymentToken(IERC20MetadataUpgradeable(address(usdc)));
        fantiumNFT.setUserManager(userManager);
        fantiumNFT.setBaseURI("https://app.fantium.com/api/metadata/");
        fantiumNFT.setTreasury(fantiumNFT_treasuryPrimary);

        // Configure collections
        CollectionJson[] memory collections = abi.decode(loadFixture("collections.json"), (CollectionJson[]));
        for (uint256 i = 0; i < collections.length; i++) {
            CollectionJson memory collection = collections[i];
            uint256 collectionId = fantiumNFT.createCollection(
                CollectionData({
                    athleteAddress: collection.athleteAddress,
                    athletePrimarySalesBPS: collection.athletePrimarySalesBPS,
                    athleteSecondarySalesBPS: collection.athleteSecondarySalesBPS,
                    fantiumSecondarySalesBPS: collection.fantiumSecondarySalesBPS,
                    launchTimestamp: collection.launchTimestamp,
                    maxInvocations: collection.maxInvocations,
                    otherEarningShare1e7: collection.otherEarningShare1e7,
                    price: collection.price,
                    tournamentEarningShare1e7: collection.tournamentEarningShare1e7
                })
            );

            // By default, collections are not mintable, set them as mintable/paused if needed
            fantiumNFT.setCollectionStatus(collectionId, collection.isMintable, collection.isPaused);
        }
        vm.stopPrank();
    }

    function prepareSale(
        uint256 collectionId,
        uint24 quantity,
        address recipient
    )
        public
        returns (
            uint256 amountUSDC,
            uint256 fantiumRevenue,
            address payable fantiumAddress,
            uint256 athleteRevenue,
            address payable athleteAddress
        )
    {
        Collection memory collection = fantiumNFT.collections(collectionId);
        amountUSDC = collection.price * quantity * 10 ** usdc.decimals();

        (fantiumRevenue, fantiumAddress, athleteRevenue, athleteAddress) =
            fantiumNFT.getPrimaryRevenueSplits(collectionId, amountUSDC);
        if (block.timestamp < collection.launchTimestamp) {
            vm.warp(collection.launchTimestamp + 1);
        }

        deal(address(usdc), recipient, amountUSDC);

        vm.prank(userManager_kycManager);
        userManager.setKYC(recipient, true);

        vm.prank(recipient);
        usdc.approve(address(fantiumNFT), amountUSDC);
    }

    function prepareSale(
        uint256 collectionId,
        uint24 quantity,
        address recipient,
        uint256 amountUSDC
    )
        public
        returns (
            bytes memory signature,
            uint256 nonce,
            uint256 fantiumRevenue,
            address fantiumAddress,
            uint256 athleteRevenue,
            address athleteAddress
        )
    {
        Collection memory collection = fantiumNFT.collections(collectionId);
        (fantiumRevenue, fantiumAddress, athleteRevenue, athleteAddress) =
            fantiumNFT.getPrimaryRevenueSplits(collectionId, amountUSDC);
        nonce = fantiumNFT.nonces(recipient);

        if (block.timestamp < collection.launchTimestamp) {
            vm.warp(collection.launchTimestamp + 1);
        }

        deal(address(usdc), recipient, amountUSDC);

        vm.prank(userManager_kycManager);
        userManager.setKYC(recipient, true);

        vm.prank(recipient);
        usdc.approve(address(fantiumNFT), amountUSDC);

        return (
            signMint(recipient, nonce, collectionId, quantity, amountUSDC),
            nonce,
            fantiumRevenue,
            fantiumAddress,
            athleteRevenue,
            athleteAddress
        );
    }

    function mintTo(uint256 collectionId, uint24 quantity, address recipient) public returns (uint256 lastTokenId) {
        prepareSale(collectionId, quantity, recipient);
        vm.prank(recipient);
        return fantiumNFT.mintTo(collectionId, quantity, recipient);
    }

    function signMint(
        address recipient,
        uint256 nonce,
        uint256 collectionId,
        uint24 quantity,
        uint256 amount
    )
        public
        view
        returns (bytes memory)
    {
        bytes32 hash = keccak256(abi.encode(collectionId, quantity, recipient, amount, nonce)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(fantiumNFT_signerKey, hash);
        return abi.encodePacked(r, s, v);
    }
}
