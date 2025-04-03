// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IFANtiumMarketplace, Offer } from "../src/interfaces/IFANtiumMarketplace.sol";

import { IFANtiumNFT } from "../src/interfaces/IFANtiumNFT.sol";
import { FANtiumMarketplaceFactory } from "./setup/FANtiumMarketplace.t.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { BaseTest } from "test/BaseTest.sol";

contract FANtiumMarketplaceV1Test is BaseTest, FANtiumMarketplaceFactory {
    // pause
    // ========================================================================
    function test_pause_ok_admin() public {
        vm.prank(fantiumMarketplace_admin);
        fantiumMarketplace.pause();
        assertTrue(fantiumMarketplace.paused());
    }

    function test_pause_revert_unauthorized() public {
        address unauthorized = makeAddr("unauthorized");

        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        vm.prank(unauthorized);
        fantiumMarketplace.pause();
    }

    // unpause
    // ========================================================================
    function test_unpause_ok_admin() public {
        // First pause the contract
        vm.prank(fantiumMarketplace_admin);
        fantiumMarketplace.pause();
        assertTrue(fantiumMarketplace.paused());

        // Then unpause it
        vm.prank(fantiumMarketplace_admin);
        fantiumMarketplace.unpause();
        assertFalse(fantiumMarketplace.paused());
    }

    function test_unpause_revert_unauthorized() public {
        // First pause the contract
        vm.prank(fantiumMarketplace_admin);
        fantiumMarketplace.pause();
        assertTrue(fantiumMarketplace.paused());

        address unauthorized = makeAddr("unauthorized");

        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        vm.prank(unauthorized);
        fantiumMarketplace.unpause();
    }

    // setTreasuryAddress
    // ========================================================================
    function test_setTreasuryAddress_ok() public {
        address newTreasury = makeAddr("newTreasury");
        vm.prank(fantiumMarketplace_admin);
        vm.expectEmit(true, true, true, true);
        emit TreasuryAddressUpdate(newTreasury);
        fantiumMarketplace.setTreasuryAddress(newTreasury);
        assertEq(fantiumMarketplace.treasury(), newTreasury);
    }

    function test_setTreasuryAddress_revert_invalidAddress() public {
        vm.prank(fantiumMarketplace_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumMarketplace.InvalidTreasuryAddress.selector, address(0)));
        fantiumMarketplace.setTreasuryAddress(address(0));
    }

    function test_setTreasuryAddress_revert_sameTreasuryAddress() public {
        address newTreasury = makeAddr("newTreasury");
        vm.prank(fantiumMarketplace_admin);
        fantiumMarketplace.setTreasuryAddress(newTreasury);
        assertEq(fantiumMarketplace.treasury(), newTreasury);
        vm.prank(fantiumMarketplace_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumMarketplace.TreasuryAddressAlreadySet.selector, newTreasury));
        fantiumMarketplace.setTreasuryAddress(newTreasury);
    }

    function test_setTreasuryAddress_revert_nonOwner() public {
        address newTreasury = makeAddr("newTreasury");
        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        fantiumMarketplace.setTreasuryAddress(newTreasury);
    }

    // setFANtiumNFTContract
    // ========================================================================
    function test_setFANtiumNFTContract_ok() public {
        address newFANtiumNFTContract = makeAddr("newFANtiumNFTContract");

        vm.startPrank(fantiumMarketplace_admin);

        // Initially, the NFT contract should be address(0)
        assertEq(address(fantiumMarketplace.nftContract()), address(0));

        // set new address
        fantiumMarketplace.setFANtiumNFTContract(IFANtiumNFT(newFANtiumNFTContract));

        assertEq(address(fantiumMarketplace.nftContract()), newFANtiumNFTContract);

        vm.stopPrank();
    }

    function test_setFANtiumNFTContract_revert_nonOwner() public {
        address newFANtiumNFTContract = makeAddr("newFANtiumNFTContract");
        address randomUser = makeAddr("random");

        vm.startPrank(randomUser);

        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        // try to set new address
        fantiumMarketplace.setFANtiumNFTContract(IFANtiumNFT(newFANtiumNFTContract));

        vm.stopPrank();
    }

    // setUsdcContractAddress
    // ========================================================================`
    function test_setUsdcContractAddress_ok() public {
        address newUSDCAddress = makeAddr("newUSDCContract");

        vm.startPrank(fantiumMarketplace_admin);

        // Initially, the NFT contract should be address(0)
        assertEq(address(fantiumMarketplace.usdcContractAddress()), address(0));

        // set new address
        fantiumMarketplace.setUsdcContractAddress(newUSDCAddress);

        assertEq(fantiumMarketplace.usdcContractAddress(), newUSDCAddress);

        vm.stopPrank();
    }

    function test_setUsdcContractAddress_revert_nonOwner() public {
        address newUSDCAddress = makeAddr("newUSDCContract");
        address randomUser = makeAddr("random");

        vm.startPrank(randomUser);

        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        // try to set new address
        fantiumMarketplace.setUsdcContractAddress(newUSDCAddress);

        vm.stopPrank();
    }

    // executeOffer // todo: continue with the rest of the test
    // ========================================================================
    //    function test_executeOffer_ok() public {
    //        Offer memory offer = Offer({
    //            seller: 0xAAAAb8A44732De44021aac698944Ec1D47cF9031,
    //            tokenAddress: 0x999999cf1046e68e36E1aA2E0E07105eDDD1f08E,
    //            tokenId: 1,
    //            amount: 1,
    //            fee: 1,
    //            expiresAt: 1
    //        });
    //
    //        // this signature is generated by Mat's script
    //        bytes memory signature =
    //            hex"1bcd0eb3f18ba7c5647f667217d15f475f0194fd8c94bd13d98cbf18a3482cb526842444a50ce7133e10ee29b5c1ccb7a9b5520039f1ac9ea873375f4b839b781c";
    //
    //        fantiumMarketplace.executeOffer(offer, signature);
    //    }
}
