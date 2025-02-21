// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC721AQueryableUpgradeable } from "erc721a-upgradeable/interfaces/IERC721AQueryableUpgradeable.sol";

// todo: add packages to the Smart Contract
// 1. change schema - done
// 2. change purchase function - done
// 3. change addPhase function - done
// 4. change removePhase function - done
// 5. change getCurrentPhase function - done
// 6. add addPackage function - done
// 7. add removePackage function - done
// 8. add view function getAllPackagesForPhase - done
// 9. add setReservedSupplyForPhase function - done
// 10. fix broken unit tests
// 11. add new unit tests

struct Package {
    uint256 packageId;
    string name; // "Classic", "Advanced", "Premium"
    uint256 price; // Package price
    uint256 shareCount; // Number of shares included in 1 package
    uint256 currentSupply; // Number of times this package has been purchased
    uint256 maxSupply; // Max number of times this package can be purchased
}

struct Phase {
    uint256 phaseId;
    uint256 pricePerShare;
    uint256 maxSupply; // Total number of shares
    uint256 reservedSupply; // Shares reserved for packages
    uint256 currentSupply; // Number of minted shares for the phase (<= maxSupply)
    uint256 startTime;
    uint256 endTime;
    mapping(uint256 => Package) packages; // Mapping of packageId to Package
}

// Struct for external view functions (without mapping)
struct PhaseView {
    uint256 phaseId;
    uint256 pricePerShare;
    uint256 maxSupply;
    uint256 reservedSupply;
    uint256 currentSupply;
    uint256 startTime;
    uint256 endTime;
}

// A phase has a certain number of NFTs available at a certain price
// Once the phase n is exhausted, the phase n+1 is automatically opened
// The price per share of phase n is < the price per share at the phase n+1
// When the last phase is exhausted, it’s not possible to purchase any further share
interface IFANtiumToken is IERC721AQueryableUpgradeable {
    // events
    event FANtiumTokenSale(uint256 quantity, address indexed recipient, uint256 amount);
    event TreasuryAddressUpdate(address newWalletAddress);

    // errors
    error PhaseDoesNotExist(uint256 phaseIndex);
    error CurrentPhaseIsNotActive();
    error NoPhasesAdded();
    error IncorrectStartOrEndTime(uint256 startTime, uint256 endTime);
    error CannotRemovePhaseWhichAlreadyStarted();
    error PreviousAndNextPhaseTimesOverlap();
    error CannotSetEndedPhaseAsCurrentPhase();
    error IncorrectSharePrice(uint256 price);
    error IncorrectMaxSupply(uint256 maxSupply);
    error IncorrectPhaseIndex(uint256 index);
    error IncorrectTokenQuantity(uint256 quantity);
    error QuantityExceedsMaxSupplyLimit(uint256 quantity);
    error MaxSupplyLimitExceeded(uint256 supply);
    error IncorrectSupplyValue(uint256 supply);
    error PhaseWithIdDoesNotExist(uint256 id);
    error IncorrectEndTime(uint256 endTime);
    error IncorrectStartTime(uint256 startTime);
    error ERC20PaymentTokenIsNotSet();
    error InvalidPaymentTokenAddress(address token);
    error InvalidTreasuryAddress(address treasury);
    error TreasuryAddressAlreadySet(address wallet);
    error InvalidMaxSupplyValue(uint256 maxSupply);
    error CannotUpdateEndedSalePhase();
    error TreasuryIsNotSet();
    error PackageDoesNotExist(uint256 packageId);
    error PackageQuantityExceedsMaxSupplyLimit(uint256 quantity);
    error PhaseNotFound(uint256 phaseId);
    error IncorrectPackagePrice(uint256 price);
    error IncorrectPackageName(string name);
    error IncorrectShareCount(uint256 shareCount);
}
