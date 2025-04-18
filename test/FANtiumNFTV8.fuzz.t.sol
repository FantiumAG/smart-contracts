// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { Collection, CollectionData, IFANtiumNFT } from "src/interfaces/IFANtiumNFT.sol";
import { BaseTest } from "test/BaseTest.sol";
import { FANtiumNFTFactory } from "test/setup/FANtiumNFTFactory.sol";

contract FANtiumNFTV8FuzzTest is BaseTest, FANtiumNFTFactory {
    function setUp() public override {
        FANtiumNFTFactory.setUp();
    }

    // mintTo (standard price)
    // ========================================================================
    function testFuzz_mintTo_standardPrice_ok(address recipient) public {
        vm.assume(recipient != address(0));

        uint256 collectionId = 1; // collection 1 is mintable
        uint24 quantity = 1;

        (
            uint256 amountUSDC,
            uint256 fantiumRevenue,
            address payable fantiumAddress,
            uint256 athleteRevenue,
            address payable athleteAddress
        ) = prepareSale(collectionId, quantity, recipient);
        vm.assume(recipient != fantiumAddress && recipient != athleteAddress);

        uint256 recipientBalanceBefore = usdc.balanceOf(recipient);
        uint256 fantiumBalanceBefore = usdc.balanceOf(fantiumAddress);
        uint256 athleteBalanceBefore = usdc.balanceOf(athleteAddress);

        // Expect Sale event
        vm.expectEmit(true, true, false, true, address(fantiumNFT));
        emit IFANtiumNFT.Sale(collectionId, quantity, recipient, amountUSDC, 0);

        vm.prank(recipient);
        uint256 lastTokenId = fantiumNFT.mintTo(collectionId, quantity, recipient);

        assertEq(fantiumNFT.ownerOf(lastTokenId), recipient);
        assertEq(usdc.balanceOf(recipient), recipientBalanceBefore - amountUSDC);
        assertEq(usdc.balanceOf(fantiumAddress), fantiumBalanceBefore + fantiumRevenue);
        assertEq(usdc.balanceOf(athleteAddress), athleteBalanceBefore + athleteRevenue);
    }

    function testFuzz_mintTo_standardPrice_ok_batch(address recipient, uint24 quantity) public {
        vm.assume(recipient != address(0));

        uint256 collectionId = 1; // collection 1 is mintable
        quantity = uint24(
            bound(
                uint256(quantity),
                1,
                fantiumNFT.collections(collectionId).maxInvocations - fantiumNFT.collections(collectionId).invocations
            )
        );

        (
            uint256 amountUSDC,
            uint256 fantiumRevenue,
            address payable fantiumAddress,
            uint256 athleteRevenue,
            address payable athleteAddress
        ) = prepareSale(collectionId, quantity, recipient);
        vm.assume(recipient != fantiumAddress && recipient != athleteAddress);

        // Store initial balances
        uint256[3] memory balancesBefore =
            [usdc.balanceOf(recipient), usdc.balanceOf(fantiumAddress), usdc.balanceOf(athleteAddress)];

        // Expect ERC20 Transfer events
        vm.expectEmit(true, true, false, true, address(usdc));
        emit IERC20Upgradeable.Transfer(recipient, fantiumAddress, fantiumRevenue);
        vm.expectEmit(true, true, false, true, address(usdc));
        emit IERC20Upgradeable.Transfer(recipient, athleteAddress, athleteRevenue);

        // Expect Sale event
        vm.expectEmit(true, true, false, true, address(fantiumNFT));
        emit IFANtiumNFT.Sale(collectionId, quantity, recipient, amountUSDC, 0);

        vm.prank(recipient);
        uint256 lastTokenId = fantiumNFT.mintTo(collectionId, quantity, recipient);

        // Verify ownership
        for (uint256 i = 0; i < quantity; i++) {
            assertEq(fantiumNFT.ownerOf(lastTokenId - i), recipient);
        }

        // Verify ERC20 transfers
        assertEq(usdc.balanceOf(recipient), balancesBefore[0] - amountUSDC);
        assertEq(usdc.balanceOf(fantiumAddress), balancesBefore[1] + fantiumRevenue);
        assertEq(usdc.balanceOf(athleteAddress), balancesBefore[2] + athleteRevenue);
    }

    // getPrimaryRevenueSplits
    // ========================================================================
    function testFuzz_getPrimaryRevenueSplits_ok(uint256 price) public view {
        vm.assume(0 < price && price < 1_000_000 * 10 ** usdc.decimals());
        uint256 collectionId = 1; // Using collection 1 from fixtures

        (uint256 fantiumRevenue, address payable fantiumAddress, uint256 athleteRevenue, address payable athleteAddress)
        = fantiumNFT.getPrimaryRevenueSplits(collectionId, price);

        // Get collection to verify calculations
        Collection memory collection = fantiumNFT.collections(collectionId);

        // Verify revenue splits
        assertEq(athleteRevenue, (price * collection.athletePrimarySalesBPS) / 10_000, "Incorrect athlete revenue");
        assertEq(fantiumRevenue, price - athleteRevenue, "Incorrect fantium revenue");

        // Verify addresses
        assertEq(fantiumAddress, fantiumNFT.treasury(), "Incorrect treasury address");
        assertEq(athleteAddress, collection.athleteAddress, "Incorrect athlete address");
    }

    function testFuzz_getPrimaryRevenueSplits_newCollection(uint256 athletePrimarySalesBPS, uint256 price) public {
        vm.assume(0 < athletePrimarySalesBPS && athletePrimarySalesBPS < 10_000);
        vm.assume(0 < price && price < 1_000_000 * 10 ** usdc.decimals());

        vm.startPrank(fantiumNFT_admin);
        uint256 collectionId = fantiumNFT.createCollection(
            CollectionData({
                athleteAddress: fantiumNFT_athlete,
                athletePrimarySalesBPS: athletePrimarySalesBPS,
                athleteSecondarySalesBPS: 0,
                fantiumSecondarySalesBPS: 0,
                launchTimestamp: block.timestamp,
                maxInvocations: 1000,
                otherEarningShare1e7: 0,
                price: price,
                tournamentEarningShare1e7: 0
            })
        );
        vm.stopPrank();

        (uint256 fantiumRevenue, address payable fantiumAddress, uint256 athleteRevenue, address payable athleteAddress)
        = fantiumNFT.getPrimaryRevenueSplits(collectionId, price);

        // Verify revenue splits
        assertEq(athleteRevenue, (price * athletePrimarySalesBPS) / 10_000, "Incorrect athlete revenue");
        assertEq(fantiumRevenue, price - athleteRevenue, "Incorrect fantium revenue");

        // Verify addresses
        assertEq(fantiumAddress, fantiumNFT_treasuryPrimary, "Incorrect fantium address");
        assertEq(athleteAddress, fantiumNFT_athlete, "Incorrect athlete address");
    }
}
