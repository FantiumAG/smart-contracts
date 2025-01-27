// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC721AQueryableUpgradeable} from "erc721a-upgradeable/interfaces/IERC721AQueryableUpgradeable.sol";

enum CollectionErrorReason {
    INVALID_DATES,
    INVALID_NAME,
    INVALID_MAX_SUPPLY,
    INVALID_PRICE,
    MAX_SUPPLY_BELOW_SUPPLY,
    START_DATE_MISMATCH
}

enum MintErrorReason {
    MINT_NOT_STARTED,
    MINT_CLOSED,
    MINT_NOT_ENOUGHT_MONEY,
    MINT_PAUSED,
    MINT_BAD_ADDRESS,
    MINT_ERC20_NOT_ACCEPTED,
    COLLECTION_NOT_EXISTING,
    MINT_MAX_SUPPLY_REACH
}

// TODO: open / close dates
// TODO: isPaused
struct FootballCollection {
    string name;
    uint256 priceUSD; // in USD (decimals = 0)
    uint256 supply; // current number of tokens of this collection in circulation
    uint256 maxSupply; // max number of tokens of this collection
    uint256 startDate; // Start date of the mint
    uint256 closeDate; // End date of the mint
    bool isPaused; // Can pause the mint
}

struct UpdateFootballCollection {
    string name;
    uint256 priceUSD; // in USD (decimals = 0)
    uint256 maxSupply; // max number of tokens of this collection}
}

interface IFootballTokenV1 is IERC721AQueryableUpgradeable {
    // ========================================================================
    // Events
    // ========================================================================
    event CollectionCreated(uint256 indexed collectionId, FootballCollection collection);
    event CollectionUpdated(uint256 indexed collectionId, FootballCollection collection);
    event TokensMinted(uint256 indexed collectionId, address indexed recipient, uint256[] tokens);
    // ========================================================================
    // Errors
    // ========================================================================
    error InvalidCollectionData(CollectionErrorReason errorReason);
    error MintError(MintErrorReason errorReason);
}
