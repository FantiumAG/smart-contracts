// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20MetadataUpgradeable } from
"@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
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
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);
        Phase memory addedPhase = fantiumToken.getAllPhases()[0];
        assertEq(addedPhase.pricePerShare, pricePerShare);
        assertEq(addedPhase.maxSupply, maxSupply);
        assertEq(addedPhase.startTime, startTime);
        assertEq(addedPhase.endTime, endTime);
        assertEq(addedPhase.currentSupply, 0); // initially set to 0
        assertEq(addedPhase.phaseId, 0); // initially set to 0
    }

    function test_addPhase_revert_IncorrectStartOrEndTime() public {
        // Setup test data
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 2 days);
        uint256 endTime = uint256(block.timestamp + 1 days); // incorrect: start time after end time

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectStartOrEndTime.selector, startTime, endTime));
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
    }

    function test_addPhase_revert_IncorrectSharePrice() public {
        // Setup test data
        uint256 pricePerShare = 0; // incorrect
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectSharePrice.selector, pricePerShare));
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
    }

    function test_addPhase_revert_IncorrectMaxSupply() public {
        // Setup test data
        uint256 pricePerShare = 10;
        uint256 maxSupply = 0; // incorrect
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectMaxSupply.selector, maxSupply));
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
    }

    function test_addPhase_revert_PreviousAndNextPhaseTimesOverlap() public {
        // Setup test data for Phase 1
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase was added
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Setup test data for Phase 2
        uint256 startTime2 = uint256(block.timestamp + 29 days); // incorrect - overlaps with Phase 1
        uint256 endTime2 = uint256(block.timestamp + 60 days);

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.PreviousAndNextPhaseTimesOverlap.selector));

        fantiumToken.addPhase(pricePerShare, maxSupply, startTime2, endTime2);
    }

    function test_addPhase_revert_nonOwner() public {
        // Setup test data
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert();
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
    }

    // removePhase
    // ========================================================================
    function test_removePhase_ok_singlePhase() public {
        // Setup test data
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // remove phase
        vm.prank(fantiumToken_admin);
        fantiumToken.removePhase(0);

        // Verify phase was removed
        assertEq(fantiumToken.getAllPhases().length, 0);
    }

    function test_removePhase_ok_multiplePhases() public {
        // Setup test data Phase 1
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Execute phase 1 addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);

        // Setup test data Phase 2
        uint256 pricePerShare2 = 200;
        uint256 maxSupply2 = 2000;
        uint256 startTime2 = uint256(block.timestamp + 31 days); // Use relative time from current block
        uint256 endTime2 = uint256(block.timestamp + 60 days); // Use relative time from current block

        // Execute phase 2 addition
        fantiumToken.addPhase(pricePerShare2, maxSupply2, startTime2, endTime2);

        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 2);

        // remove the phase 1
        fantiumToken.removePhase(0);

        // Verify phase was removed
        assertEq(fantiumToken.getAllPhases().length, 1);
        // Verify the phase 1 was removed and Phase 2 is preserved
        assertEq(fantiumToken.getAllPhases()[0].pricePerShare, pricePerShare2);

        vm.stopPrank();
    }

    function test_removePhase_revert_IncorrectPhaseIndex() public {
        // Setup test data
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // remove phase
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectPhaseIndex.selector, 2));
        fantiumToken.removePhase(2); // incorrect index
    }

    function test_removePhase_revert_CannotRemovePhaseWhichAlreadyStarted() public {
        // Setup test data
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time to after the phase has started
        vm.warp(startTime + 10 days); // phase has started

        // remove phase
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.CannotRemovePhaseWhichAlreadyStarted.selector));
        fantiumToken.removePhase(0);
    }

    function test_removePhase_revert_nonOwner() public {
        // Setup test data
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // remove phase
        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert();
        fantiumToken.removePhase(0);
    }

    // setCurrentPhase
    // ========================================================================
    function test_setCurrentPhase_ok() public {
        // add phases
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 startTime2 = uint256(block.timestamp + 31 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block
        uint256 endTime2 = uint256(block.timestamp + 60 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase 1 addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Execute phase 2 addition
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime2, endTime2);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 2);

        // try to set phase 1 as current phase
        fantiumToken.setCurrentPhase(0);
        vm.assertEq(fantiumToken.getCurrentPhase().phaseId, 0);

        // try to set phase 2 as current phase
        fantiumToken.setCurrentPhase(1);
        vm.assertEq(fantiumToken.getCurrentPhase().phaseId, 1);

        vm.stopPrank();
    }

    function test_setCurrentPhase_revert_IncorrectPhaseIndex() public {
        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectPhaseIndex.selector, 2));
        fantiumToken.setCurrentPhase(2);
    }

    function test_setCurrentPhase_revert_CannotSetEndedPhaseAsCurrentPhase() public {
        // add phases
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 startTime2 = uint256(block.timestamp + 31 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block
        uint256 endTime2 = uint256(block.timestamp + 60 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase 1 addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Execute phase 2 addition
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime2, endTime2);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 2);

        // Warp time to after the phase has started
        vm.warp(startTime + 50 days); // phase 1 has ended

        // try to set ended phase 1 as current phase
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.CannotSetEndedPhaseAsCurrentPhase.selector));
        fantiumToken.setCurrentPhase(0);

        vm.stopPrank();
    }

    function test_setCurrentPhase_revert_nonOwner() public {
        // add phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

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
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // set phase as current
        vm.prank(fantiumToken_admin);
        fantiumToken.setCurrentPhase(0);

        // check that getCurrentPhase returns correct phase data
        vm.assertEq(fantiumToken.getCurrentPhase().phaseId, 0);
        vm.assertEq(fantiumToken.getCurrentPhase().pricePerShare, pricePerShare);
        vm.assertEq(fantiumToken.getCurrentPhase().maxSupply, maxSupply);
        vm.assertEq(fantiumToken.getCurrentPhase().startTime, startTime);
        vm.assertEq(fantiumToken.getCurrentPhase().endTime, endTime);
    }

    function test_getCurrentPhase_revert_NoPhasesAdded() public {
        // Check the initial state - no phases added
        assertEq(fantiumToken.getAllPhases().length, 0);

        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.NoPhasesAdded.selector));
        fantiumToken.getCurrentPhase();
    }

    // getAllPhases
    // ========================================================================
    function test_getAllPhases_ok() public {
        // add 2 phases
        uint256 pricePerShare = 100;
        uint256 pricePerShare2 = 200;
        uint256 maxSupply = 1000;
        uint256 maxSupply2 = 2000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 startTime2 = uint256(block.timestamp + 31 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block
        uint256 endTime2 = uint256(block.timestamp + 60 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase 1 addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Execute phase 2 addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare2, maxSupply2, startTime2, endTime2);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 2);

        // check that getAllPhases returns correct data
        fantiumToken.getAllPhases();
        Phase[] memory allPhases = fantiumToken.getAllPhases();
        vm.assertEq(allPhases[0].phaseId, 0);
        vm.assertEq(allPhases[0].pricePerShare, pricePerShare);
        vm.assertEq(allPhases[0].maxSupply, maxSupply);
        vm.assertEq(allPhases[0].startTime, startTime);
        vm.assertEq(allPhases[1].phaseId, 1);
        vm.assertEq(allPhases[1].pricePerShare, pricePerShare2);
        vm.assertEq(allPhases[1].maxSupply, maxSupply2);
        vm.assertEq(allPhases[1].startTime, startTime2);
    }

    // changePhaseEndTime
    // ========================================================================
    function test_changePhaseEndTime_ok() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 2 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);
        assertEq(fantiumToken.getAllPhases()[0].endTime, endTime);

        uint256 mockNewEndTime = uint256(block.timestamp + 40 days);
        // change end time
        vm.prank(fantiumToken_admin);
        fantiumToken.changePhaseEndTime(mockNewEndTime, 0);
        // check that it has been changed
        vm.assertEq(fantiumToken.getAllPhases()[0].endTime, mockNewEndTime);
    }

    function test_changePhaseEndTime_revert_PhaseWithIdDoesNotExist() public {
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.PhaseWithIdDoesNotExist.selector, 1));
        fantiumToken.changePhaseEndTime(endTime, 1);
    }

    function test_changePhaseEndTime_revert_IncorrectEndTime() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 2 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        uint256 mockNewEndTime = uint256(block.timestamp + 1 days); // incorrect - before the start time

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectEndTime.selector, mockNewEndTime));
        fantiumToken.changePhaseEndTime(mockNewEndTime, 0);
    }

    function test_changePhaseEndTime_revert_PreviousAndNextPhaseTimesOverlap() public {
        // add 2 phases
        uint256 pricePerShare = 100;
        uint256 pricePerShare2 = 200;
        uint256 maxSupply = 1000;
        uint256 maxSupply2 = 2000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block
        uint256 startTime2 = uint256(block.timestamp + 31 days); // Use relative time from current block
        uint256 endTime2 = uint256(block.timestamp + 60 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase 1 addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Execute phase 2 addition
        fantiumToken.addPhase(pricePerShare2, maxSupply2, startTime2, endTime2);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 2);

        uint256 mockNewEndTime = uint256(block.timestamp + 32 days); // incorrect - overlaps with phase 2

        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.PreviousAndNextPhaseTimesOverlap.selector));
        fantiumToken.changePhaseEndTime(mockNewEndTime, 0);

        vm.stopPrank();
    }

    // nonOwner
    function test_changePhaseEndTime_revert_nonOwner() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 2 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        uint256 mockNewEndTime = uint256(block.timestamp + 31 days);

        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert();
        fantiumToken.changePhaseEndTime(mockNewEndTime, 0);
    }

    // changePhaseStartTime
    // ========================================================================
    function test_changePhaseStartTime_ok() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 2 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);
        assertEq(fantiumToken.getAllPhases()[0].endTime, endTime);

        uint256 mockNewStartTime = uint256(block.timestamp + 3 days);
        // change start time
        vm.prank(fantiumToken_admin);
        fantiumToken.changePhaseStartTime(mockNewStartTime, 0);
        // check that it has been changed
        vm.assertEq(fantiumToken.getAllPhases()[0].startTime, mockNewStartTime);
    }

    function test_changePhaseStartTime_revert_PhaseWithIdDoesNotExist() public {
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.PhaseWithIdDoesNotExist.selector, 1));
        fantiumToken.changePhaseEndTime(endTime, 1);
    }

    function test_changePhaseStartTime_revert_IncorrectStartTime() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 2 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        uint256 mockNewStartTime = uint256(block.timestamp + 31 days); // incorrect - after the end time

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectStartTime.selector, mockNewStartTime));
        fantiumToken.changePhaseStartTime(mockNewStartTime, 0);
    }

    function test_changePhaseStartTime_revert_PreviousAndNextPhaseTimesOverlap() public {
        // add 2 phases
        uint256 pricePerShare = 100;
        uint256 pricePerShare2 = 200;
        uint256 maxSupply = 1000;
        uint256 maxSupply2 = 2000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block
        uint256 startTime2 = uint256(block.timestamp + 31 days); // Use relative time from current block
        uint256 endTime2 = uint256(block.timestamp + 60 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase 1 addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Execute phase 2 addition
        fantiumToken.addPhase(pricePerShare2, maxSupply2, startTime2, endTime2);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 2);

        uint256 mockNewStartTime = uint256(block.timestamp + 29 days); // incorrect - overlaps with phase 1

        // try to set new start time for phase 2, which overlaps with phase 1
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.PreviousAndNextPhaseTimesOverlap.selector));
        fantiumToken.changePhaseStartTime(mockNewStartTime, 1);

        vm.stopPrank();
    }

    // nonOwner
    function test_changePhaseStartTime_revert_nonOwner() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 2 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        uint256 mockNewStartTime = uint256(block.timestamp + 3 days);

        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert();
        fantiumToken.changePhaseStartTime(mockNewStartTime, 0);
    }

    // changePhaseMaxSupply
    // ========================================================================
    function test_changePhaseMaxSupply_ok() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        uint256 newmaxSupply = 5000;

        // change max supply
        vm.prank(fantiumToken_admin);
        fantiumToken.changePhaseMaxSupply(newmaxSupply, 0);
        vm.assertEq(fantiumToken.getAllPhases()[0].maxSupply, newmaxSupply);
    }

    function test_changePhaseMaxSupply_revert_PhaseWithIdDoesNotExist() public {
        uint256 maxSupply = 1000;

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.PhaseWithIdDoesNotExist.selector, 1));
        fantiumToken.changePhaseMaxSupply(maxSupply, 1);
    }

    // InvalidMaxSupplyValue
    function test_changePhaseMaxSupply_revert_InvalidMaxSupplyValue() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.InvalidMaxSupplyValue.selector, 0));
        fantiumToken.changePhaseMaxSupply(0, 0); // passing maxSupply 0
    }

    // CannotUpdateEndedSalePhase
    function test_changePhaseMaxSupply_revert_CannotUpdateEndedSalePhase() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time to after the phase has started
        vm.warp(endTime + 1 days); // phase has ended

        uint256 newmaxSupply = 5000;

        vm.prank(fantiumToken_admin);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.CannotUpdateEndedSalePhase.selector));
        fantiumToken.changePhaseMaxSupply(newmaxSupply, 0); // passing maxSupply 0
    }

    // nonOwner
    function test_changePhaseMaxSupply_revert_nonOwner() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days); // Use relative time from current block
        uint256 endTime = uint256(block.timestamp + 30 days); // Use relative time from current block

        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);

        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        uint256 newmaxSupply = 5000;

        address nonAdmin = makeAddr("random");
        vm.prank(nonAdmin);
        vm.expectRevert();
        fantiumToken.changePhaseMaxSupply(newmaxSupply, 0);
    }

    // mintTo
    // ========================================================================
    function test_mintTo_ok() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time
        vm.warp(startTime + 1 days); // phase is active

        // set the payment token
        address usdcAddress = address(usdc);
        fantiumToken.setPaymentToken(usdcAddress, true);
        assertTrue(fantiumToken.erc20PaymentTokens(usdcAddress));

        // set treasury
        address newTreasury = makeAddr("newTreasury");
        fantiumToken.setTreasuryAddress(newTreasury);

        vm.stopPrank();

        // prepare sale
        address recipient = makeAddr('recipient');
        uint256 quantity = 20;
        uint8 tokenDecimals = IERC20MetadataUpgradeable(usdcAddress).decimals();
        uint256 expectedAmount = quantity * pricePerShare * 10 ** tokenDecimals;
        // top up recipient
        deal(usdcAddress, recipient, expectedAmount);
        vm.startPrank(recipient);
        // approve the spending
        usdc.approve(address(fantiumToken), expectedAmount);

        // mint
        vm.expectEmit(true, true, true, true); // check that event was emitted
        emit FANtiumTokenSale(quantity, recipient, expectedAmount);
        fantiumToken.mintTo(recipient, quantity, usdcAddress);

        // check that currentSupply has increased
        assertEq(fantiumToken.getCurrentPhase().currentSupply, quantity);

        vm.stopPrank();
    }

    // ok with automatic current phase switch
    function test_mintTo_ok_autoSwitchPhase() public {
        // add 2 phases
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        uint256 pricePerShare2 = 200;
        uint256 maxSupply2 = 2000;
        uint256 startTime2 = uint256(block.timestamp + 31 days);
        uint256 endTime2 = uint256(block.timestamp + 60 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.startPrank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        fantiumToken.addPhase(pricePerShare2, maxSupply2, startTime2, endTime2);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 2);

        // Warp time
        vm.warp(startTime + 1 days); // phase 1 is active

        // set the payment token
        address usdcAddress = address(usdc);
        fantiumToken.setPaymentToken(usdcAddress, true);
        assertTrue(fantiumToken.erc20PaymentTokens(usdcAddress));

        // set treasury
        address newTreasury = makeAddr("newTreasury");
        fantiumToken.setTreasuryAddress(newTreasury);

        vm.stopPrank();

        // prepare sale
        address recipient = makeAddr('recipient');
        uint256 quantity = 1000; // equal to maxSupply for the Phase 1
        uint8 tokenDecimals = IERC20MetadataUpgradeable(usdcAddress).decimals();
        uint256 expectedAmount = quantity * pricePerShare * 10 ** tokenDecimals;
        // top up recipient
        deal(usdcAddress, recipient, expectedAmount);
        vm.startPrank(recipient);
        // approve the spending
        usdc.approve(address(fantiumToken), expectedAmount);

        // check the active phase before the mint
        assertEq(fantiumToken.getCurrentPhase().phaseId, 0);

        // mint
        vm.expectEmit(true, true, true, true); // check that event was emitted
        emit FANtiumTokenSale(quantity, recipient, expectedAmount);
        fantiumToken.mintTo(recipient, quantity, usdcAddress);

        // check that currentSupply has increased
        assertEq(fantiumToken.getAllPhases()[0].currentSupply, quantity);
        // check that current phase is switched to the next one
        assertEq(fantiumToken.getCurrentPhase().phaseId, 1);

        vm.stopPrank();
    }

    function test_mintTo_revert_CurrentPhaseIsNotActive_phaseEnded() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time to after the phase has ended
        vm.warp(endTime + 1 days); // phase has ended

        // try to mint
        address recipient = makeAddr('recipient');
        address usdcAddress = address(usdc);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.CurrentPhaseIsNotActive.selector));
        fantiumToken.mintTo(recipient, 10, usdcAddress);
    }

    function test_mintTo_revert_CurrentPhaseIsNotActive_phaseNotStarted() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 2 days); // phase will start in 2 days!
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // try to mint
        address recipient = makeAddr('recipient');
        address usdcAddress = address(usdc);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.CurrentPhaseIsNotActive.selector));
        fantiumToken.mintTo(recipient, 10, usdcAddress);
    }

    // IncorrectTokenQuantity
    function test_mintTo_revert_IncorrectTokenQuantity() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time
        vm.warp(startTime + 1 days); // phase is active

        // try to mint
        address recipient = makeAddr('recipient');
        address usdcAddress = address(usdc);
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.IncorrectTokenQuantity.selector, 0));
        fantiumToken.mintTo(recipient, 0, usdcAddress); // passing quantity 0 !
    }

    // QuantityExceedsMaxSupplyLimit
    function test_mintTo_revert_QuantityExceedsMaxSupplyLimit() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time
        vm.warp(startTime + 1 days); // phase is active

        // try to mint
        address recipient = makeAddr('recipient');
        address usdcAddress = address(usdc);
        uint256 quantity = 1001; // more than maxSupply
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.QuantityExceedsMaxSupplyLimit.selector, quantity));
        fantiumToken.mintTo(recipient, quantity, usdcAddress);
    }

    // ERC20PaymentTokenIsNotSet
    function test_mintTo_revert_ERC20PaymentTokenIsNotSet() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time
        vm.warp(startTime + 1 days); // phase is active

        // try to mint
        address recipient = makeAddr('recipient');
        address usdcAddress = address(usdc);
        uint256 quantity = 20;
        // we skip the step of setting the payment token
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.ERC20PaymentTokenIsNotSet.selector));
        fantiumToken.mintTo(recipient, quantity, usdcAddress);
    }

    // TreasuryIsNotSet
    function test_mintTo_revert_TreasuryIsNotSet() public {
        // add a phase
        uint256 pricePerShare = 100;
        uint256 maxSupply = 1000;
        uint256 startTime = uint256(block.timestamp + 1 days);
        uint256 endTime = uint256(block.timestamp + 30 days);
        // Check the initial state
        assertEq(fantiumToken.getAllPhases().length, 0);
        // Execute phase addition
        vm.prank(fantiumToken_admin);
        fantiumToken.addPhase(pricePerShare, maxSupply, startTime, endTime);
        // Verify phase data was stored correctly
        assertEq(fantiumToken.getAllPhases().length, 1);

        // Warp time
        vm.warp(startTime + 1 days); // phase is active

        // set the payment token
        address usdcAddress = address(usdc);
        vm.prank(fantiumToken_admin);
        fantiumToken.setPaymentToken(usdcAddress, true);
        assertTrue(fantiumToken.erc20PaymentTokens(usdcAddress));

        // try to mint
        address recipient = makeAddr('recipient');
        uint256 quantity = 20;
        vm.expectRevert(abi.encodeWithSelector(IFANtiumToken.TreasuryIsNotSet.selector));
        fantiumToken.mintTo(recipient, quantity, usdcAddress);
    }
}
