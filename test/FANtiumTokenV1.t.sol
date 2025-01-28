// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../src/interfaces/IFANtiumToken.sol";
import "./setup/FANtiumTokenFactory.sol";
import { BaseTest } from "test/BaseTest.sol";
import { IFANtiumToken } from "src/interfaces/IFANtiumToken.sol";

contract FANtiumTokenV1Test is BaseTest, FANtiumTokenFactory {
    // setTreasuryAddress
    // ========================================================================
    function test_setTreasuryAddress_ok() public {
        address newTreasury = makeAddr("newTreasury");
        vm.prank(fantiumToken_admin);
        vm.expectEmit(true, true, true, true);
        emit TreasuryAddressUpdate(newTreasury);
        fantiumToken.setTreasuryAddress(newTreasury);
        assertEq(fantiumToken.treasury(), newTreasury);
    }

    function test_setTreasuryAddress_revert_invalidAddress() public {
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.InvalidTreasuryAddress.selector, address(0)));
        fantiumToken.setTreasuryAddress(address(0));
    }

    function test_setTreasuryAddress_revert_sameTreasuryAddress() public {
        address newTreasury = makeAddr("newTreasury");
        vm.prank(fantiumToken_admin);
        fantiumToken.setTreasuryAddress(newTreasury);
        assertEq(fantiumToken.treasury(), newTreasury);
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.TreasuryAddressAlreadySet.selector, newTreasury));
        fantiumToken.setTreasuryAddress(newTreasury);
    }

    function test_setTreasuryAddress_revert_nonOwner() public {
        address newTreasury = makeAddr("newTreasury");
        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert();
        fantiumToken.setTreasuryAddress(newTreasury);
    }

    // setPaymentToken
    // ========================================================================
    function test_setPaymentToken_ok() public {
        address usdcAddress = address(usdc);
        vm.prank(fantiumToken_admin);
        fantiumToken.setPaymentToken(usdcAddress, true);
        assertTrue(fantiumToken.erc20PaymentTokens(usdcAddress));
    }

    function test_setPaymentToken_ok_disableToken() public {
        // we need to add some token first
        address usdcAddress = address(usdc);
        vm.prank(fantiumToken_admin);
        fantiumToken.setPaymentToken(usdcAddress, true);
        assertTrue(fantiumToken.erc20PaymentTokens(usdcAddress));

        // test that you can disable previously added payment token
        vm.prank(fantiumToken_admin);
        fantiumToken.setPaymentToken(usdcAddress, false);
        assertFalse(fantiumToken.erc20PaymentTokens(usdcAddress));
    }

    function test_setPaymentToken_revert_InvalidPaymentTokenAddress() public {
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.InvalidPaymentTokenAddress.selector, address(0)));
        fantiumToken.setPaymentToken(address(0), true);
    }

    function test_setPaymentToken_revert_nonOwner() public {
        address usdcAddress = address(usdc);
        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert();
        fantiumToken.setPaymentToken(usdcAddress, true);
    }

    // addPhase
    // ========================================================================
    function test_addPhase_ok() public {
        // Setup test data
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertTrue(fantiumToken.getAllPhases().length == 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);
        Phase memory addedPhase = fantiumToken.getAllPhases()[0];
        assertEq(addedPhase.pricePerShare, mockPricePerShare);
        assertEq(addedPhase.maxSupply, mockMaxSupply);
        assertEq(addedPhase.startTime, mockStartTime);
        assertEq(addedPhase.endTime, mockEndTime);
        assertEq(addedPhase.currentSupply, 0); // initially set to 0
        assertEq(addedPhase.phaseId, 0); // initially set to 0
    }

    function test_addPhase_revert_IncorrectStartOrEndTime() public {
        // Setup test data
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 2 days);
        uint256 mockEndTime = uint256(block.timestamp + 1 days); // incorrect: start time after end time

        vm.prank(fantiumToken_admin);
        vm.expectRevert(
            abi.encodeWithSelector(IFANtiumToken.IncorrectStartOrEndTime.selector, mockStartTime, mockEndTime)
        );
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
    }

    function test_addPhase_revert_IncorrectSharePrice() public {
        // Setup test data
        uint256 mockPricePerShare = 0; // incorrect
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days);
        uint256 mockEndTime = uint256(block.timestamp + 30 days);

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectSharePrice.selector, mockPricePerShare));
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
    }

    function test_addPhase_revert_IncorrectMaxSupply() public {
        // Setup test data
        uint256 mockPricePerShare = 10;
        uint256 mockMaxSupply = 0; // incorrect
        uint256 mockStartTime = uint256(block.timestamp + 1 days);
        uint256 mockEndTime = uint256(block.timestamp + 30 days);

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectMaxSupply.selector, mockMaxSupply));
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
    }

    function test_addPhase_revert_PreviousAndNextPhaseTimesOverlap() public {
        // Setup test data for Phase 1
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase was added
        assertTrue(fantiumToken.getAllPhases().length == 1);

        // Setup test data for Phase 2
        uint256 mockStartTime2 = uint256(block.timestamp + 29 days); // incorrect - overlaps with Phase 1
        uint256 mockEndTime2 = uint256(block.timestamp + 60 days);

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.PreviousAndNextPhaseTimesOverlap.selector));

        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime2, mockEndTime2);
    }

    function test_addPhase_revert_nonOwner() public {
        // Setup test data
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert();
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
    }

    // removePhase
    // ========================================================================
    function test_removePhase_ok_singlePhase() public {
        // Setup test data
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);

        // remove phase
        vm.prank(fantiumToken_admin);
        fantiumToken.removePhase(0);

        // Verify phase was removed
        assertTrue(fantiumToken.getAllPhases().length == 0);
    }

    function test_removePhase_ok_multiplePhases() public {
        // Setup test data Phase 1
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Execute phase 1 addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);

        // Setup test data Phase 2
        uint256 mockPricePerShare2 = 200;
        uint256 mockMaxSupply2 = 2000;
        uint256 mockStartTime2 = uint256(block.timestamp + 31 days); // Use relative time from current block
        uint256 mockEndTime2 = uint256(block.timestamp + 60 days); // Use relative time from current block

        // Execute phase 2 addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare2, mockMaxSupply2, mockStartTime2, mockEndTime2);

        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 2);

        // remove the phase 1
        vm.prank(fantiumToken_admin);
        fantiumToken.removePhase(0);

        // Verify phase was removed
        assertTrue(fantiumToken.getAllPhases().length == 1);
        // Verify the phase 1 was removed and Phase 2 is preserved
        assertEq(fantiumToken.getAllPhases()[0].pricePerShare, mockPricePerShare2);
    }

    function test_removePhase_revert_IncorrectPhaseIndex() public {
        // Setup test data
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);

        // remove phase
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectPhaseIndex.selector, 2));
        fantiumToken.removePhase(2); // incorrect index
    }

    function test_removePhase_revert_CannotRemovePhaseWhichAlreadyStarted() public {
        // Setup test data
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days);
        uint256 mockEndTime = uint256(block.timestamp + 30 days);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);

        // Warp time to after the phase has started
        vm.warp(mockStartTime + 10 days); // phase has started

        // remove phase
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.CannotRemovePhaseWhichAlreadyStarted.selector));
        fantiumToken.removePhase(0);
    }

    function test_removePhase_revert_nonOwner() public {
        // Setup test data
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days);
        uint256 mockEndTime = uint256(block.timestamp + 30 days);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);

        // remove phase
        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert();
        fantiumToken.removePhase(0);
    }

    // setCurrentPhase
    // ========================================================================
    function test_setCurrentPhase_revert_IncorrectPhaseIndex() public {
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectPhaseIndex.selector, 2));
        fantiumToken.setCurrentPhase(2);
    }

    function test_setCurrentPhase_revert_CannotSetEndedPhaseAsCurrentPhase() public {
        // add phases
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 mockStartTime2 = uint256(block.timestamp + 31 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block
        uint256 mockEndTime2 = uint256(block.timestamp + 60 days); // Use relative time from current block

        // Check the initial state
        assertTrue(fantiumToken.getAllPhases().length == 0);

        // Execute phase 1 addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);

        // Execute phase 2 addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime2, mockEndTime2);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 2);

        // Warp time to after the phase has started
        vm.warp(mockStartTime + 50 days); // phase 1 has ended

        // try to set ended phase 1 as current phase
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.CannotSetEndedPhaseAsCurrentPhase.selector));
        fantiumToken.setCurrentPhase(0);
    }

    function test_setCurrentPhase_ok() public {
        // add phases
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 mockStartTime2 = uint256(block.timestamp + 31 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block
        uint256 mockEndTime2 = uint256(block.timestamp + 60 days); // Use relative time from current block

        // Check the initial state
        assertTrue(fantiumToken.getAllPhases().length == 0);

        // Execute phase 1 addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);

        // Execute phase 2 addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime2, mockEndTime2);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 2);

        // try to set phase 1 as current phase
        vm.prank(fantiumToken_admin);
        fantiumToken.setCurrentPhase(0);
        vm.assertEq(fantiumToken.getCurrentPhase().phaseId, 0);

        // try to set phase 2 as current phase
        vm.prank(fantiumToken_admin);
        fantiumToken.setCurrentPhase(1);
        vm.assertEq(fantiumToken.getCurrentPhase().phaseId, 1);
    }

    function test_setCurrentPhase_revert_nonOwner() public {
        // add phase
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertTrue(fantiumToken.getAllPhases().length == 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);

        // try to set phase as current phase
        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert();
        fantiumToken.setCurrentPhase(0);
    }

    // getCurrentPhase
    // ========================================================================
    function test_getCurrentPhase_ok() public {
        // add a phase
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertTrue(fantiumToken.getAllPhases().length == 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);

        // set phase as current
        vm.prank(fantiumToken_admin);
        fantiumToken.setCurrentPhase(0);

        // check that getCurrentPhase returns correct phase data
        vm.assertEq(fantiumToken.getCurrentPhase().phaseId, 0);
        vm.assertEq(fantiumToken.getCurrentPhase().pricePerShare, mockPricePerShare);
        vm.assertEq(fantiumToken.getCurrentPhase().maxSupply, mockMaxSupply);
        vm.assertEq(fantiumToken.getCurrentPhase().startTime, mockStartTime);
        vm.assertEq(fantiumToken.getCurrentPhase().endTime, mockEndTime);
    }

    function test_getCurrentPhase_revert_NoPhasesAdded() public {
        // Check the initial state - no phases added
        assertTrue(fantiumToken.getAllPhases().length == 0);

        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.NoPhasesAdded.selector));
        fantiumToken.getCurrentPhase();
    }

    // getAllPhases
    // ========================================================================
    function test_getAllPhases_ok() public {
        // add 2 phases
        uint256 mockPricePerShare = 100;
        uint256 mockPricePerShare2 = 200;
        uint256 mockMaxSupply = 1000;
        uint256 mockMaxSupply2 = 2000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 mockStartTime2 = uint256(block.timestamp + 31 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block
        uint256 mockEndTime2 = uint256(block.timestamp + 60 days); // Use relative time from current block

        // Check the initial state
        assertTrue(fantiumToken.getAllPhases().length == 0);

        // Execute phase 1 addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);

        // Execute phase 2 addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare2, mockMaxSupply2, mockStartTime2, mockEndTime2);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 2);

        // check that getAllPhases returns correct data
        fantiumToken.getAllPhases();
        Phase[] memory allPhases = fantiumToken.getAllPhases();
        vm.assertEq(allPhases[0].phaseId, 0);
        vm.assertEq(allPhases[0].pricePerShare, mockPricePerShare);
        vm.assertEq(allPhases[0].maxSupply, mockMaxSupply);
        vm.assertEq(allPhases[0].startTime, mockStartTime);
        vm.assertEq(allPhases[1].phaseId, 1);
        vm.assertEq(allPhases[1].pricePerShare, mockPricePerShare2);
        vm.assertEq(allPhases[1].maxSupply, mockMaxSupply2);
        vm.assertEq(allPhases[1].startTime, mockStartTime2);
    }

    // changePhaseEndTime
    // ========================================================================
    function test_changePhaseEndTime_revert_PhaseWithIdDoesNotExist() public {
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.PhaseWithIdDoesNotExist.selector, 1));
        fantiumToken.changePhaseEndTime(mockEndTime, 1);
    }

    function test_changePhaseEndTime_revert_IncorrectEndTime() public {
        // add a phase
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 2 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertTrue(fantiumToken.getAllPhases().length == 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);

        uint256 mockNewEndTime = uint256(block.timestamp + 1 days); // incorrect - before the start time

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectEndTime.selector, mockNewEndTime));
        fantiumToken.changePhaseEndTime(mockNewEndTime, 0);
    }

    function test_changePhaseEndTime_revert_PreviousAndNextPhaseTimesOverlap() public {
        // add 2 phases
        uint256 mockPricePerShare = 100;
        uint256 mockPricePerShare2 = 200;
        uint256 mockMaxSupply = 1000;
        uint256 mockMaxSupply2 = 2000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block
        uint256 mockStartTime2 = uint256(block.timestamp + 31 days); // Use relative time from current block
        uint256 mockEndTime2 = uint256(block.timestamp + 60 days); // Use relative time from current block

        // Check the initial state
        assertTrue(fantiumToken.getAllPhases().length == 0);

        // Execute phase 1 addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);

        // Execute phase 2 addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare2, mockMaxSupply2, mockStartTime2, mockEndTime2);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 2);

        uint256 mockNewEndTime = uint256(block.timestamp + 32 days); // incorrect - overlaps with phase 2

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.PreviousAndNextPhaseTimesOverlap.selector));
        fantiumToken.changePhaseEndTime(mockNewEndTime, 0);
    }

    // nonOwner
    function test_changePhaseEndTime_revert_nonOwner() public {
        // add a phase
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 2 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertTrue(fantiumToken.getAllPhases().length == 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);

        uint256 mockNewEndTime = uint256(block.timestamp + 31 days);

        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert();
        fantiumToken.changePhaseEndTime(mockNewEndTime, 0);
    }

    // ok
    function test_changePhaseEndTime_ok() public {
        // add a phase
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 2 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertTrue(fantiumToken.getAllPhases().length == 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);
        assertEq(fantiumToken.getAllPhases()[0].endTime, mockEndTime);

        uint256 mockNewEndTime = uint256(block.timestamp + 40 days);
        // change end time
        vm.prank(fantiumToken_admin);
        fantiumToken.changePhaseEndTime(mockNewEndTime, 0);
        // check that it has been changed
        vm.assertEq(fantiumToken.getAllPhases()[0].endTime, mockNewEndTime);
    }

    // changePhaseStartTime
    // ========================================================================
    function test_changePhaseStartTime_revert_PhaseWithIdDoesNotExist() public {
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.PhaseWithIdDoesNotExist.selector, 1));
        fantiumToken.changePhaseEndTime(mockEndTime, 1);
    }

    function test_changePhaseStartTime_revert_IncorrectStartTime() public {
        // add a phase
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 2 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertTrue(fantiumToken.getAllPhases().length == 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);

        uint256 mockNewStartTime = uint256(block.timestamp + 31 days); // incorrect - after the end time

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectStartTime.selector, mockNewStartTime));
        fantiumToken.changePhaseStartTime(mockNewStartTime, 0);
    }

    function test_changePhaseStartTime_revert_PreviousAndNextPhaseTimesOverlap() public {
        // add 2 phases
        uint256 mockPricePerShare = 100;
        uint256 mockPricePerShare2 = 200;
        uint256 mockMaxSupply = 1000;
        uint256 mockMaxSupply2 = 2000;
        uint256 mockStartTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block
        uint256 mockStartTime2 = uint256(block.timestamp + 31 days); // Use relative time from current block
        uint256 mockEndTime2 = uint256(block.timestamp + 60 days); // Use relative time from current block

        // Check the initial state
        assertTrue(fantiumToken.getAllPhases().length == 0);

        // Execute phase 1 addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);

        // Execute phase 2 addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare2, mockMaxSupply2, mockStartTime2, mockEndTime2);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 2);

        uint256 mockNewStartTime = uint256(block.timestamp + 29 days); // incorrect - overlaps with phase 1

        // try to set new start time for phase 2, which overlaps with phase 1
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.PreviousAndNextPhaseTimesOverlap.selector));
        fantiumToken.changePhaseStartTime(mockNewStartTime, 1);
    }

    // nonOwner
    function test_changePhaseStartTime_revert_nonOwner() public {
        // add a phase
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 2 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertTrue(fantiumToken.getAllPhases().length == 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);

        uint256 mockNewStartTime = uint256(block.timestamp + 3 days);

        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert();
        fantiumToken.changePhaseStartTime(mockNewStartTime, 0);
    }

    // ok
    function test_changePhaseStartTime_ok() public {
        // add a phase
        uint256 mockPricePerShare = 100;
        uint256 mockMaxSupply = 1000;
        uint256 mockStartTime = uint256(block.timestamp + 2 days); // Use relative time from current block
        uint256 mockEndTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertTrue(fantiumToken.getAllPhases().length == 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(mockPricePerShare, mockMaxSupply, mockStartTime, mockEndTime);
        // Verify phase data was stored correctly
        assertTrue(fantiumToken.getAllPhases().length == 1);
        assertEq(fantiumToken.getAllPhases()[0].endTime, mockEndTime);

        uint256 mockNewStartTime = uint256(block.timestamp + 3 days);
        // change start time
        vm.prank(fantiumToken_admin);
        fantiumToken.changePhaseStartTime(mockNewStartTime, 0);
        // check that it has been changed
        vm.assertEq(fantiumToken.getAllPhases()[0].startTime, mockNewStartTime);
    }
}
