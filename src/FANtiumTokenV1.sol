// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { ERC721AQueryableUpgradeable } from "erc721a-upgradeable/extensions/ERC721AQueryableUpgradeable.sol";

import { IFANtiumToken, Package, Phase } from "./interfaces/IFANtiumToken.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { IERC20MetadataUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";

/**
 * @title FANtium Token (FAN) smart contract
 * @author Alex Chernetsky, Mathieu Bour - FANtium AG
 */
contract FANtiumTokenV1 is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ERC721AQueryableUpgradeable,
    OwnableRoles,
    IFANtiumToken
{
    // ========================================================================
    // Constants
    // ========================================================================
    string private constant NAME = "FANtium Token";
    string private constant SYMBOL = "FAN";

    // Roles
    // ========================================================================
    uint256 public constant SIGNER_ROLE = _ROLE_0;

    // ========================================================================
    // State variables
    // ========================================================================
    uint256 private nextPhaseId; // has default value 0
    Phase[] public phases;
    uint256 public currentPhaseIndex;
    address public treasury; // Safe that will receive all the funds
    string public baseURI; // The base URI for the token metadata.

    /**
     * @notice The ERC20 tokens used for payments, dollar stable coins (e.g. USDC, USDT, DAI).
     * we count that all dollar stable coins have the same value 1:1
     */
    mapping(address => bool) public erc20PaymentTokens;

    function initialize(address admin) public initializerERC721A initializer {
        __UUPSUpgradeable_init();
        __ERC721A_init(NAME, SYMBOL);
        _initializeOwner(admin);
    }

    /**
     * @notice Implementation of the upgrade authorization logic
     * @dev Restricted to the owner
     */
    function _authorizeUpgrade(address) internal view override {
        _checkOwner();
    }

    // ========================================================================
    // Pause
    // ========================================================================
    /**
     * @notice Update contract pause status to `_paused`.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses contract
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ========================================================================
    // ERC2771
    // ========================================================================
    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return hasAllRoles(forwarder, SIGNER_ROLE);
    }

    function _msgSender() internal view virtual override returns (address sender) {
        if (isTrustedForwarder(msg.sender)) {
            // The assembly code is more direct than the Solidity version using `abi.decode`.
            /// @solidity memory-safe-assembly
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }

    function _msgSenderERC721A() internal view virtual override returns (address) {
        return _msgSender();
    }

    function _msgData() internal view virtual override returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }

    // ========================================================================
    // Setters
    // ========================================================================
    /**
     * Set treasury address - FANtium address where the funds should be transferred
     * @param wallet - address of the treasury
     */
    function setTreasuryAddress(address wallet) external onlyOwner {
        // Ensure the token address is not zero
        if (wallet == address(0)) {
            revert InvalidTreasuryAddress(wallet);
        }

        // Ensure the treasury address is not the same as the current one
        if (wallet == treasury) {
            revert TreasuryAddressAlreadySet(wallet);
        }

        // update the treasury address
        treasury = wallet;

        // emit an event for transparency
        emit TreasuryAddressUpdate(wallet);
    }

    /**
     * Set payment token
     * @param token - address of the contract to be set as the payment token
     * @param isEnabled - boolean, true if token should be enabled as a means of payment, otherwise - false
     */
    function setPaymentToken(address token, bool isEnabled) external onlyOwner {
        // Ensure the token address is not zero
        if (token == address(0)) {
            revert InvalidPaymentTokenAddress(token);
        }

        // set the payment token
        erc20PaymentTokens[token] = isEnabled;
    }

    /**
     * Add a new sale phase
     * @param pricePerShare Price of a single share
     * @param maxSupply Maximum amount of shares in the sale phase
     * @param startTime Time of the sale start
     * @param endTime Time of the sale end
     */
    function addPhase(
        uint256 pricePerShare,
        uint256 maxSupply,
        uint256 startTime,
        uint256 endTime
    )
        external
        onlyOwner
    {
        // validate incoming data
        if (endTime <= startTime || startTime <= block.timestamp) {
            // End time must be after start time
            // StartTime should be a date in the future
            revert IncorrectStartOrEndTime(startTime, endTime);
        }

        if (pricePerShare == 0) {
            // Price per token must be greater than zero
            revert IncorrectSharePrice(pricePerShare);
        }

        if (maxSupply == 0) {
            // Max supply must be greater than zero
            revert IncorrectMaxSupply(maxSupply);
        }

        // Check if there are any existing phases
        if (phases.length > 0) {
            Phase memory latestPhase = phases[phases.length - 1];
            // check that previous and next phase do not overlap
            if (latestPhase.endTime >= startTime) {
                revert PreviousAndNextPhaseTimesOverlap();
            }
        }

        // add new Phase
        phases.push(
            Phase({
                phaseId: nextPhaseId,
                nextPackageId: 0,
                pricePerShare: pricePerShare,
                maxSupply: maxSupply,
                startTime: startTime,
                endTime: endTime,
                currentSupply: 0,
                packages: new Package[](0)
            })
        );

        // increment counter
        nextPhaseId++;
    }

    /**
     * Add a new package to the sale phase
     * @param name Name of the package, e.g. Premium
     * @param price Price of the package
     * @param shareCount Number of shares per package
     * @param maxSupply Number of packages
     * @param phaseId id of the sale phase, where we want to add the package
     */
    function addPackage(
        string calldata name,
        uint256 price,
        uint256 shareCount,
        uint256 maxSupply,
        uint256 phaseId
    )
        external
        onlyOwner
    {
        // validate input data
        // calldata strings do not support .length
        if (bytes(name).length == 0) {
            revert IncorrectPackageName(name);
        }

        if (price == 0) {
            // Price must be greater than zero
            revert IncorrectPackagePrice(price);
        }

        if (shareCount <= 1) {
            // There should be more than 1 share per package
            revert IncorrectShareCount(shareCount);
        }

        if (maxSupply == 0) {
            // Max supply must be greater than zero
            revert IncorrectMaxSupply(maxSupply);
        }

        // get phase
        (Phase memory phase, uint256 phaseIndex) = _findPhaseById(phaseId);

        // phase was found, add new package
        phases[phaseIndex].packages.push(
            Package({
                packageId: phase.nextPackageId,
                name: name,
                price: price,
                shareCount: shareCount,
                currentSupply: 0,
                maxSupply: maxSupply
            })
        );

        // increment counter
        phases[phaseIndex].nextPackageId++;
    }

    /**
     * Private function that helps to find a package in an array of packages by id
     * @param packageId id of the package
     * @param packages array of all packages
     * @return (package, index) - returns package that was found and the index of the found package
     */
    function _findPackageById(
        uint256 packageId,
        Package[] memory packages
    )
        private
        pure
        returns (Package memory, uint256)
    {
        for (uint256 i = 0; i < packages.length; i++) {
            if (packages[i].packageId == packageId) {
                return (packages[i], i);
            }
        }
        revert PackageDoesNotExist(packageId);
    }

    /**
     * Remove existing package from the sale phase
     * @param phaseId id of the phase
     * @param packageId id of the package to be removed
     */
    function removePackage(uint256 phaseId, uint256 packageId) external onlyOwner {
        // check that phase exists
        (Phase memory phase, uint256 phaseIndex) = _findPhaseById(phaseId);
        // check that package exists
        (, uint256 index) = _findPackageById(packageId, phase.packages);

        // remove the package from the phase
        // Swap with the last element
        phases[phaseIndex].packages[index] = phase.packages[phase.packages.length - 1];
        // Remove the last element
        phases[phaseIndex].packages.pop();
    }

    /**
     * Remove the existing sale phase
     * @param phaseIndex The index of the sale phase
     */
    function removePhase(uint256 phaseIndex) external onlyOwner {
        // check that phaseIndex is valid
        if (phaseIndex >= phases.length) {
            revert IncorrectPhaseIndex(phaseIndex);
        }

        Phase memory phaseToRemove = phases[phaseIndex];

        // check that phase has not started yet, we cannot remove phase which already started
        if (phaseToRemove.startTime < block.timestamp) {
            revert CannotRemovePhaseWhichAlreadyStarted();
        }

        // remove the phase from the array, preserve the order of the items
        // shift all elements after the index to the left
        for (uint256 i = phaseIndex; i < phases.length - 1; i++) {
            phases[i] = phases[i + 1];
        }

        phases.pop(); // remove the last element
    }

    /**
     * Set currentPhaseIndex and therefore the current sale phase
     * @param phaseIndex The index of the sale phase
     */
    function setCurrentPhase(uint256 phaseIndex) public onlyOwner {
        // check that phaseIndex is valid
        if (phaseIndex >= phases.length) {
            revert IncorrectPhaseIndex(phaseIndex);
        }

        // we cannot set past phase as a current phase
        Phase memory phaseToBeSet = phases[phaseIndex];
        if (phaseToBeSet.endTime <= block.timestamp) {
            revert CannotSetEndedPhaseAsCurrentPhase();
        }

        currentPhaseIndex = phaseIndex;
    }

    /**
     * Internal function to only be used in the mintTo function for auto phase switch
     * We cannot use setCurrentPhase in mintTo because it's only available for owner
     * Function sets currentPhaseIndex and therefore the current sale phase
     * @param phaseIndex The index of the sale phase
     */
    function _setCurrentPhase(uint256 phaseIndex) internal {
        // we do checks in mintTo, so no need to double-check here
        currentPhaseIndex = phaseIndex;
    }

    /**
     * View to see the current sale phase
     * @return phase - returns current sale phase or reverts
     * @dev Reverts with NoPhasesAdded if no phases exist
     * @dev Reverts with PhaseDoesNotExist if currentPhaseIndex is invalid
     */
    function getCurrentPhase() public view returns (Phase memory) {
        // check that there are phases
        if (phases.length == 0) {
            revert NoPhasesAdded();
        }

        // verify if currentPhaseIndex is within the bounds of the phases array
        if (currentPhaseIndex >= phases.length) {
            revert PhaseDoesNotExist(currentPhaseIndex);
        }

        // return current phase
        return phases[currentPhaseIndex];
    }

    /**
     * Helper to view all existing sale phases
     * @return phases - array of all sale phases
     */
    function getAllPhases() public view returns (Phase[] memory) {
        return phases;
    }

    /**
     * Helper to view all existing packages in the sale phase
     * @param phaseId - sale phase id
     * @return Package[] - packages array
     */
    function getAllPackagesForPhase(uint256 phaseId) external view returns (Package[] memory) {
        // check that phase exists
        (Phase memory phase,) = _findPhaseById(phaseId);

        // return all packages
        return phase.packages;
    }

    /**
     * Get phase from an array by phaseId
     * @param id - phase id
     * @return Phase which was found, or default values - if not found.
     * @return uint256 index of the Phase in an array, 0 - if not found.
     */
    function _findPhaseById(uint256 id) private view returns (Phase memory, uint256) {
        for (uint256 i = 0; i < phases.length; i++) {
            if (phases[i].phaseId == id) {
                return (phases[i], i); // Return (Phase, index) if phase is found
            }
        }

        // Instead of returning an invalid struct, we revert if not found.
        revert PhaseNotFound(id);
    }

    /**
     * Change start time of the specific sale phase
     * @param newStartTime new sale phase start time to be set
     * @param phaseId id of the sale phase
     */
    function changePhaseStartTime(uint256 newStartTime, uint256 phaseId) external onlyOwner {
        (Phase memory phase, uint256 phaseIndex) = _findPhaseById(phaseId);

        // validate newStartTime
        if (newStartTime > phase.endTime || block.timestamp > newStartTime) {
            // End time must be after start time
            // Start time should be a date in future
            revert IncorrectStartTime(newStartTime);
        }

        // Explicitly check for out-of-bounds access when dealing with previousPhase
        if (phases.length > 1 && phaseIndex != 0) {
            // check that phases do not overlap
            Phase memory previousPhase = phases[phaseIndex - 1];
            if (previousPhase.endTime > newStartTime) {
                revert PreviousAndNextPhaseTimesOverlap();
            }
        }

        // change the start time
        phases[phaseIndex].startTime = newStartTime;
    }

    /**
     * Change end time of the specific sale phase
     * @param newEndTime new sale phase end time to be set
     * @param phaseId id of the sale phase
     */
    function changePhaseEndTime(uint256 newEndTime, uint256 phaseId) external onlyOwner {
        (Phase memory phase, uint256 phaseIndex) = _findPhaseById(phaseId);

        // validate newEndTime
        if (newEndTime <= phase.startTime || block.timestamp > newEndTime) {
            // End time must be after start time
            // End time should be a date in future
            revert IncorrectEndTime(newEndTime);
        }

        // Explicitly check for out-of-bounds access when dealing with nextPhase
        if (phaseIndex + 1 < phases.length) {
            // check that phases do not overlap
            Phase memory nextPhase = phases[phaseIndex + 1];
            if (nextPhase.startTime < newEndTime) {
                revert PreviousAndNextPhaseTimesOverlap();
            }
        }

        // update the end time
        phases[phaseIndex].endTime = newEndTime;
    }

    /**
     * Change current supply of the active sale phase
     * Internal function, which is only used by the mintTo function
     * @param currentSupply how many tokens has been minted already
     */
    function _changePhaseCurrentSupply(uint256 currentSupply) internal {
        Phase storage currentPhase = phases[currentPhaseIndex];
        // check that currentSupply does not exceed the max limit
        if (currentSupply > currentPhase.maxSupply) {
            revert MaxSupplyLimitExceeded(currentSupply);
        }
        if (currentSupply < currentPhase.currentSupply) {
            // check that currentSupply is bigger than the prev value
            revert IncorrectSupplyValue(currentSupply);
        }

        // change the currentSupply value
        phases[currentPhaseIndex].currentSupply = currentSupply;
    }

    /**
     * Change current supply of the package
     * Internal function, which is only used by the mintTo function
     * @param currentSupply how many packages has been minted already
     * @param packageId id of the package to be updated
     */
    function _changePackageCurrentSupply(uint256 currentSupply, uint256 packageId) internal {
        // get current phase
        Phase memory phase = phases[currentPhaseIndex];
        (Package memory package, uint256 packageIndex) = _findPackageById(packageId, phase.packages);

        // check that currentSupply does not exceed the max limit
        if (currentSupply > package.maxSupply) {
            revert MaxSupplyLimitExceeded(currentSupply);
        }
        // check that currentSupply is bigger than the prev value
        if (currentSupply < package.currentSupply) {
            revert IncorrectSupplyValue(currentSupply);
        }

        // change the package currentSupply value
        phases[currentPhaseIndex].packages[packageIndex].currentSupply = currentSupply;
    }

    /**
     * Change max supply of the sale phase
     * External function, which can be used if business requirements change
     * @param maxSupply - new max supply value
     * @param phaseId - id of the phase to be edited
     */
    function changePhaseMaxSupply(uint256 maxSupply, uint256 phaseId) external onlyOwner {
        (Phase memory phase, uint256 phaseIndex) = _findPhaseById(phaseId);

        // max supply cannot be 0
        // max supply should be bigger than currentSupply
        if (maxSupply == 0 || maxSupply < phase.currentSupply) {
            revert InvalidMaxSupplyValue(maxSupply);
        }

        // we cannot change the max supply for the ended sale phases
        if (phase.endTime < block.timestamp) {
            revert CannotUpdateEndedSalePhase();
        }

        // update the max supply value
        phases[phaseIndex].maxSupply = maxSupply;
    }

    /**
     * Mint FAN tokens to the recipient address. Function for purchasing single shares (not packages);
     * @param recipient The recipient of the FAN tokens (can be different that the sender)
     * @param paymentToken The address of the stable coin
     * @param quantity The quantity of FAN tokens to mint
     *
     */
    function mintTo(address recipient, address paymentToken, uint256 quantity) public whenNotPaused {
        // Buying single share(s)
        // get current phase
        Phase memory phase = phases[currentPhaseIndex];

        // check that phase is active
        // should be phase.startTime < block.timestamp < phase.endTime
        if (phase.startTime > block.timestamp || phase.endTime < block.timestamp) {
            revert CurrentPhaseIsNotActive();
        }

        // check token quantity
        // no need to check if quantity is negative, because uint256 cannot be negative
        if (quantity == 0) {
            revert IncorrectTokenQuantity(quantity);
        }

        // payment token validation
        if (!erc20PaymentTokens[paymentToken]) {
            revert ERC20PaymentTokenIsNotSet();
        }

        // check if treasury is set
        if (treasury == address(0)) {
            revert TreasuryIsNotSet();
        }

        uint8 tokenDecimals = IERC20MetadataUpgradeable(paymentToken).decimals();
        uint256 expectedAmount = quantity * phase.pricePerShare * 10 ** tokenDecimals;

        // Ensure enough shares exist
        if (phase.currentSupply + quantity > phase.maxSupply) {
            revert QuantityExceedsMaxSupplyLimit(quantity);
        }

        // transfer stable coin from msg.sender to this treasury
        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(paymentToken), _msgSender(), treasury, expectedAmount);

        // mint the FAN tokens to the recipient
        _mint(recipient, quantity);

        // change the currentSupply in the Phase
        _changePhaseCurrentSupply(phase.currentSupply + quantity);

        // if we sold out the tokens at a certain valuation, we need to open the next stage
        // once the phase n is exhausted, the phase n+1 is automatically opened
        if (phase.currentSupply + quantity == phase.maxSupply) {
            // check if there is a phase with index = currentPhaseIndex + 1
            Phase storage nextPhase = phases[currentPhaseIndex + 1];
            if (nextPhase.pricePerShare != 0 && nextPhase.maxSupply != 0) {
                _setCurrentPhase(currentPhaseIndex + 1);
            }
        }

        // emit an event after minting tokens
        emit FANtiumTokenSale(quantity, recipient, expectedAmount, paymentToken);
    }

    /**
     * Mint FAN tokens to the recipient address. (for package purchase)
     * @param paymentToken The address of the stable coin
     * @param recipient The recipient of the FAN tokens (can be different that the sender)
     * @param packageId The id of the package
     * @param packageQuantity The quantity of packages
     */
    function mintTo(
        address recipient,
        address paymentToken,
        uint256 packageId,
        uint256 packageQuantity
    )
        public
        whenNotPaused
    {
        // Buying a package
        // get current phase
        Phase memory phase = getCurrentPhase();

        // check that phase is active
        // should be phase.startTime < block.timestamp < phase.endTime
        if (phase.startTime > block.timestamp || phase.endTime < block.timestamp) {
            revert CurrentPhaseIsNotActive();
        }

        // check packageQuantity
        // no need to check if quantity is negative, because uint256 cannot be negative
        if (packageQuantity == 0) {
            revert IncorrectPackageQuantity(packageQuantity);
        }

        // payment token validation
        if (!erc20PaymentTokens[paymentToken]) {
            revert ERC20PaymentTokenIsNotSet();
        }

        // check if treasury is set
        if (treasury == address(0)) {
            revert TreasuryIsNotSet();
        }

        // check that the package exists
        (Package memory package,) = _findPackageById(packageId, phase.packages);

        // check that package max supply is not exceeded
        if (package.currentSupply + packageQuantity > package.maxSupply) {
            revert PackageQuantityExceedsMaxSupplyLimit(packageQuantity);
        }

        // Calculate how many shares in packages
        uint256 sharesToMint = package.shareCount * packageQuantity;

        // Ensure enough shares exist for packages
        if (phase.currentSupply + sharesToMint > phase.maxSupply) {
            revert QuantityExceedsMaxSupplyLimit(sharesToMint);
        }

        // price calculation
        uint8 tokenDecimals = IERC20MetadataUpgradeable(paymentToken).decimals();
        uint256 expectedAmount = packageQuantity * package.price * 10 ** tokenDecimals;

        // transfer stable coin from msg.sender to this treasury
        SafeERC20Upgradeable.safeTransferFrom(IERC20Upgradeable(paymentToken), _msgSender(), treasury, expectedAmount);

        // mint the FAN tokens to the recipient
        _mint(recipient, sharesToMint);

        // change the currentSupply in the Phase
        _changePhaseCurrentSupply(phase.currentSupply + sharesToMint);
        // change package supply
        uint256 updatedSupply = package.currentSupply + packageQuantity;
        _changePackageCurrentSupply(updatedSupply, packageId);

        // if we sold out the tokens at a certain valuation, we need to open the next stage
        // once the phase n is exhausted, the phase n+1 is automatically opened
        if (phase.currentSupply + sharesToMint == phase.maxSupply) {
            // check if there is a phase with index = currentPhaseIndex + 1
            Phase storage nextPhase = phases[currentPhaseIndex + 1];
            if (nextPhase.pricePerShare != 0 && nextPhase.maxSupply != 0) {
                _setCurrentPhase(currentPhaseIndex + 1);
            }
        }

        // emit an event after minting tokens
        emit FANtiumTokenPackageSale(recipient, packageId, packageQuantity, sharesToMint, paymentToken, expectedAmount);
    }

    /**
     * This is MVP implementation, can be optimised later
     * Mint FAN tokens to the recipient address. (for purchasing single shares and packages at the same time)
     * @param recipient The recipient of the FAN tokens (can be different that the sender)
     * @param paymentToken The address of the stable coin
     * @param singleShares The quantity of single shares
     * @param packages Array of tuples. Each tuple contains [packageId, packageQuantity]
     */
    function batchMintTo(
        address recipient,
        address paymentToken,
        uint256 singleShares,
        uint256[2][] calldata packages
    )
        external
        whenNotPaused
    {
        // we do NOT expect to have more than 3 packages of FAN token
        if (packages.length > 3) {
            revert PackageLengthExceedsMaxLimit(packages.length);
        }

        if (singleShares > 0) {
            // mint single shares
            mintTo(recipient, paymentToken, singleShares);
        }

        if (packages.length > 0) {
            for (uint256 i = 0; i < packages.length; i++) {
                uint256 packageId = packages[i][0];
                uint256 packageQuantity = packages[i][1];
                if (packageQuantity > 0) {
                    // mint packages
                    mintTo(recipient, paymentToken, packageId, packageQuantity);
                }
            }
        }
    }

    // ========================================================================
    // Batch transfer functions
    // ========================================================================
    /**
     * @notice Batch transfer NFTs from one address to another.
     * @param from The address to transfer the NFTs from.
     * @param to The address to transfer the NFTs to.
     * @param tokenIds The IDs of the NFTs to transfer.
     */
    function batchTransferFrom(address from, address to, uint256[] memory tokenIds) public whenNotPaused {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            transferFrom(from, to, tokenIds[i]);
        }
    }

    /**
     * @notice Batch safe transfer NFTs from one address to another.
     * @param from The address to transfer the NFTs from.
     * @param to The address to transfer the NFTs to.
     * @param tokenIds The IDs of the NFTs to transfer.
     */
    function batchSafeTransferFrom(address from, address to, uint256[] memory tokenIds) public whenNotPaused {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            safeTransferFrom(from, to, tokenIds[i]);
        }
    }

    /**
     * @dev Returns the base URI for computing {tokenURI}.
     * Necessary to use the default ERC721 tokenURI function from ERC721Upgradeable.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    /**
     * @notice Sets the base URI for the token metadata.
     * @dev Restricted to owner.
     * @param baseURI_ The new base URI.
     */
    function setBaseURI(string memory baseURI_) external whenNotPaused onlyOwner {
        baseURI = baseURI_;
    }
}
