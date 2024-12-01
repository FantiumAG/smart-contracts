// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.13;

import {IERC20MetadataUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC721Upgradeable, IERC165Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ECDSAUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol";
import {DefaultOperatorFiltererUpgradeable} from "operator-filter-registry/src/upgradeable/DefaultOperatorFiltererUpgradeable.sol";
import {IFANtiumNFT, Collection, CreateCollection, UpdateCollection, CollectionErrorReason} from "./interfaces/IFANtiumNFT.sol";
import {IFANtiumUserManager} from "./interfaces/IFANtiumUserManager.sol";
import {TokenVersionUtil} from "./utils/TokenVersionUtil.sol";

/**
 * @title FANtium ERC721 contract V5.
 * @author Mathieu Bour - FANtium AG, based on previous work by MTX studio AG.
 */
contract FANtiumNFTV5 is
    Initializable,
    ERC721Upgradeable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    DefaultOperatorFiltererUpgradeable,
    PausableUpgradeable,
    IFANtiumNFT
{
    using StringsUpgradeable for uint256;
    using ECDSAUpgradeable for bytes32;

    // ========================================================================
    // Constants
    // ========================================================================
    string public constant VERSION = "5.0.0";
    string public constant NAME = "FANtium";
    string public constant SYMBOL = "FAN";

    uint256 public constant ONE_MILLION = 1_000_000;
    bytes4 private constant _INTERFACE_ID_ERC2981_OVERRIDE = 0xbb3bafd6;

    // Roles
    // ========================================================================
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PLATFORM_MANAGER_ROLE = keccak256("PLATFORM_MANAGER_ROLE");
    bytes32 public constant KYC_MANAGER_ROLE = keccak256("KYC_MANAGER_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    // Fields
    // ========================================================================
    bytes32 public constant FIELD_FANTIUM_SECONDARY_MARKET_ROYALTY_BPS = "fantium secondary royalty BPS";
    bytes32 public constant FIELD_FANTIUM_PRIMARY_ADDRESS = "fantium primary sale address";
    bytes32 public constant FIELD_FANTIUM_SECONDARY_ADDRESS = "fantium secondary sale address";
    bytes32 public constant FIELD_COLLECTION_CREATED = "created";
    bytes32 public constant FIELD_COLLECTION_NAME = "name";
    bytes32 public constant FIELD_COLLECTION_ATHLETE_NAME = "name";
    bytes32 public constant FIELD_COLLECTION_ATHLETE_ADDRESS = "athlete address";
    bytes32 public constant FIELD_COLLECTION_PAUSED = "isMintingPaused";
    bytes32 public constant FIELD_COLLECTION_PRICE = "price";
    bytes32 public constant FIELD_COLLECTION_MAX_INVOCATIONS = "max invocations";
    bytes32 public constant FIELD_COLLECTION_PRIMARY_MARKET_ROYALTY_PERCENTAGE = "collection primary sale %";
    bytes32 public constant FIELD_COLLECTION_SECONDARY_MARKET_ROYALTY_PERCENTAGE = "collection secondary sale %";
    bytes32 public constant FIELD_COLLECTION_BASE_URI = "collection base uri";
    bytes32 public constant FIELD_COLLECTION_TIER = "collection tier";
    bytes32 public constant FILED_FANTIUM_BASE_URI = "fantium base uri";
    bytes32 public constant FIELD_FANTIUM_MINTER_ADDRESS = "fantium minter address";
    bytes32 public constant FIELD_COLLECTION_ACTIVATED = "isActivated";
    bytes32 public constant FIELD_COLLECTION_LAUNCH_TIMESTAMP = "launch timestamp";

    // ========================================================================
    // State variables
    // ========================================================================
    mapping(uint256 => Collection) private _collections;
    string public baseURI;
    mapping(uint256 => mapping(address => uint256)) public UNUSED_collectionIdToAllowList;
    mapping(address => bool) public UNUSED_kycedAddresses;
    uint256 public nextCollectionId;
    address public erc20PaymentToken;
    address public claimContract;
    address public fantiumUserManager;
    address public trustedForwarder;

    // ========================================================================
    // Events
    // ========================================================================
    event Mint(address indexed _to, uint256 indexed _tokenId);
    event CollectionUpdated(uint256 indexed _collectionId, bytes32 indexed _update);
    event PlatformUpdated(bytes32 indexed _field);

    // ========================================================================
    // Errors
    // ========================================================================
    error AccountNotKYCed(address recipient);
    error CollectionDoesNotExist(uint256 collectionId);
    error CollectionNotLaunched(uint256 collectionId);
    error CollectionNotMintable(uint256 collectionId);
    error CollectionPaused(uint256 collectionId);
    error InvalidSignature();
    error RoleNotGranted(address account, bytes32 role);
    error AthleteOnly(uint256 collectionId, address account, address expected);
    error InvalidCollection(CollectionErrorReason reason);

    // ========================================================================
    // UUPS upgradeable pattern
    // ========================================================================
    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes contract.
     * @param _tokenName Name of token.
     * @param _tokenSymbol Token symbol.
     * max(uint248) to avoid overflow when adding to it.
     */
    function initialize(
        address _defaultAdmin,
        string memory _tokenName,
        string memory _tokenSymbol
    ) public initializer {
        __ERC721_init(_tokenName, _tokenSymbol);
        __UUPSUpgradeable_init();
        __AccessControl_init();
        __DefaultOperatorFilterer_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);
        _grantRole(UPGRADER_ROLE, _defaultAdmin);
        nextCollectionId = 1;
    }

    /**
     * @notice Implementation of the upgrade authorization logic
     * @dev Restricted to the UPGRADER_ROLE
     */
    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    // ========================================================================
    // Interface
    // ========================================================================
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165Upgradeable, AccessControlUpgradeable, ERC721Upgradeable) returns (bool) {
        return interfaceId == _INTERFACE_ID_ERC2981_OVERRIDE || super.supportsInterface(interfaceId);
    }

    // ========================================================================
    // Modifiers
    // ========================================================================
    modifier onlyReady() {
        require(fantiumUserManager != address(0), "UserManager not set");
        _;
    }

    modifier onlyPlatformManager() {
        if (!hasRole(PLATFORM_MANAGER_ROLE, msg.sender)) {
            revert RoleNotGranted(msg.sender, PLATFORM_MANAGER_ROLE, );
        }
        _;
    }

    modifier onlyAthlete(uint256 collectionId) {
        if (_msgSender() != _collections[collectionId].athleteAddress && !hasRole(PLATFORM_MANAGER_ROLE, msg.sender)) {
            revert AthleteOnly(collectionId, msg.sender, _collections[collectionId].athleteAddress);
        }
        _;
    }

    modifier onlyValidCollectionId(uint256 _collectionId) {
        require(_collections[_collectionId].exists == true, "Invalid collectionId");
        _;
    }

    modifier onlyValidTokenId(uint256 _tokenId) {
        require(_exists(_tokenId), "Invalid tokenId");
        _;
    }

    // ========================================================================
    // ERC2771, single trusted forwarder
    // ========================================================================
    function setTrustedForwarder(address _trustedForwarder) public onlyPlatformManager {
        trustedForwarder = _trustedForwarder;
    }

    function isTrustedForwarder(address forwarder) public view virtual returns (bool) {
        return forwarder == trustedForwarder;
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

    function _msgData() internal view virtual override returns (bytes calldata) {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }

    // ========================================================================
    // Contract setters
    // ========================================================================
    function setClaimContract(address _claimContract) external onlyPlatformManager {
        claimContract = _claimContract;
    }

    function setUserManager(address _userManager) external onlyPlatformManager {
        fantiumUserManager = _userManager;
    }

    // ========================================================================
    // Minting
    // ========================================================================
    /**
     * @notice Checks if a mint is possible for a collection
     * @param collectionId Collection ID.
     * @param quantity Amount of tokens to mint.
     * @param recipient Recipient of the mint.
     */
    function mintable(
        uint256 collectionId,
        uint24 quantity,
        address recipient
    ) public view returns (bool useAllowList) {
        if (!IFANtiumUserManager(fantiumUserManager).isAddressKYCed(_msgSender())) {
            revert AccountNotKYCed(recipient);
        }

        Collection memory collection = _collections[collectionId];

        if (!collection.exists) {
            revert CollectionDoesNotExist(collectionId);
        }

        if (collection.launchTimestamp > block.timestamp) {
            revert CollectionNotLaunched(collectionId);
        }

        if (!collection.isMintable) {
            revert CollectionNotMintable(collectionId);
        }

        // If the collection is paused, we need to check if the recipient is on the allowlist and has enough allocation
        if (collection.isPaused) {
            useAllowList = true;
            bool isAllowListed = IFANtiumUserManager(fantiumUserManager).hasAllowlist(
                address(this),
                collectionId,
                recipient
            ) >= quantity;
            if (!isAllowListed) {
                revert CollectionPaused(collectionId);
            }
        }

        return useAllowList;
    }

    /**
     * @dev Internal function to mint tokens of a collection.
     * @param collectionId Collection ID.
     * @param quantity Amount of tokens to mint.
     * @param recipient Recipient of the mint.
     */
    function _mintTo(uint256 collectionId, uint24 quantity, uint256 amount, address recipient) internal whenNotPaused {
        Collection memory collection = _collections[collectionId];
        uint256 tokenId = (collectionId * ONE_MILLION) + collection.invocations;

        // CHECKS (in the mintable function)
        bool useAllowList = mintable(collectionId, quantity, recipient);

        // EFFECTS
        _collections[collectionId].invocations += quantity;
        if (useAllowList) {
            IFANtiumUserManager(fantiumUserManager).reduceAllowListAllocation(
                collectionId,
                address(this),
                recipient,
                quantity
            );
        }

        // INTERACTIONS
        // Send funds to the treasury and athlete account.
        _splitFunds(amount, collectionId, _msgSender());

        for (uint256 i = 0; i < quantity; i++) {
            _mint(recipient, tokenId + i);
            emit Mint(recipient, tokenId + i);
        }
    }

    /**
     * @notice Purchase NFTs from the sale.
     * @param collectionId The collection ID to purchase from.
     * @param quantity The quantity of NFTs to purchase.
     * @param recipient The recipient of the NFTs.
     */
    function mintTo(uint256 collectionId, uint24 quantity, address recipient) public whenNotPaused {
        Collection memory collection = _collections[collectionId];
        uint256 amount = collection.price * quantity;
        _mintTo(collectionId, quantity, amount, recipient);
    }

    /**
     * @notice Purchase NFTs from the sale with a custom price, checked
     * @param collectionId The collection ID to purchase from.
     * @param quantity The quantity of NFTs to purchase.
     * @param amount The amount of tokens to purchase the NFTs with.
     * @param recipient The recipient of the NFTs.
     * @param signature The signature of the purchase request.
     */
    function mintTo(
        uint256 collectionId,
        uint24 quantity,
        uint256 amount,
        address recipient,
        bytes memory signature
    ) public whenNotPaused {
        bytes32 hash = keccak256(abi.encode(_msgSender(), collectionId, quantity, amount, recipient))
            .toEthSignedMessageHash();
        if (!hasRole(SIGNER_ROLE, hash.recover(signature))) {
            revert InvalidSignature();
        }

        _mintTo(collectionId, quantity, amount, recipient);
    }

    /**
     * @notice View function that returns appropriate revenue splits between
     * different FANtium, athlete given a sale price of `_price` on collection `_collectionId`.
     * This always returns two revenue amounts and two addresses, but if a
     * revenue is zero for athlete, the corresponding
     * address returned will also be null (for gas optimization).
     * Does not account for refund if user overpays for a token
     * @param _collectionId collection ID to be queried.
     * @param _price Sale price of token.
     * @return fantiumRevenue_ amount of revenue to be sent to FANtium
     * @return fantiumAddress_ address to send FANtium revenue to
     * @return athleteRevenue_ amount of revenue to be sent to athlete
     * @return athleteAddress_ address to send athlete revenue to. Will be null
     * if no revenue is due to athlete (gas optimization).
     * @dev this always returns 2 addresses and 2 revenues, but if the
     * revenue is zero, the corresponding address will be address(0). It is up
     * to the contract performing the revenue split to handle this
     * appropriately.
     */
    function getPrimaryRevenueSplits(
        uint256 _collectionId,
        uint256 _price
    )
        public
        view
        returns (
            uint256 fantiumRevenue_,
            address payable fantiumAddress_,
            uint256 athleteRevenue_,
            address payable athleteAddress_
        )
    {
        // get athlete address & revenue from collection
        Collection memory collection = _collections[_collectionId];

        // calculate revenues
        athleteRevenue_ = (_price * collection.athletePrimarySalesBPS) / 10000;

        fantiumRevenue_ = _price - athleteRevenue_;

        // set addresses from storage
        fantiumAddress_ = collection.fantiumSalesAddress;
        if (athleteRevenue_ > 0) {
            athleteAddress_ = collection.athleteAddress;
        }
    }

    /**
     * @dev splits funds between sender (if refund),
     * FANtium, and athlete for a token purchased on
     * collection `_collectionId`.
     */
    function _splitFunds(uint256 _price, uint256 _collectionId, address _sender) internal {
        // split funds between FANtium and athlete
        (
            uint256 fantiumRevenue_,
            address fantiumAddress_,
            uint256 athleteRevenue_,
            address athleteAddress_
        ) = getPrimaryRevenueSplits(_collectionId, _price);

        // FANtium payment
        if (fantiumRevenue_ > 0) {
            SafeERC20Upgradeable.safeTransferFrom(
                IERC20Upgradeable(erc20PaymentToken),
                _sender,
                fantiumAddress_,
                fantiumRevenue_
            );
        }

        // athlete payment
        if (athleteRevenue_ > 0) {
            SafeERC20Upgradeable.safeTransferFrom(
                IERC20Upgradeable(erc20PaymentToken),
                _sender,
                athleteAddress_,
                athleteRevenue_
            );
        }
    }

    // ========================================================================
    // ERC721 functions
    // ========================================================================
    function setBaseURI(string memory _baseURI) external whenNotPaused onlyPlatformManager {
        baseURI = _baseURI;
        emit PlatformUpdated(FILED_FANTIUM_BASE_URI);
    }

    /**
     * @notice Gets token URI for token ID `_tokenId`.
     * @dev token URIs are the concatenation of the collection base URI and the
     * token ID.
     */
    function tokenURI(uint256 _tokenId) public view override onlyValidTokenId(_tokenId) returns (string memory) {
        return string(bytes.concat(bytes(baseURI), bytes(_tokenId.toString())));
    }

    // ========================================================================
    // Pause
    // ========================================================================
    /**
     * @notice Update contract pause status to `_paused`.
     */
    function pause() external onlyPlatformManager {
        _pause();
    }

    /**
     * @notice Unpauses contract
     */
    function unpause() external onlyPlatformManager {
        _unpause();
    }

    // ========================================================================
    // ERC721 collections
    // ========================================================================
    function collections(uint256 _collectionId) external view returns (Collection memory) {
        return _collections[_collectionId];
    }

    function getCollectionAthleteAddress(uint256 _collectionId) external view returns (address) {
        return _collections[_collectionId].athleteAddress;
    }

    function getEarningsShares1e7(uint256 _collectionId) external view returns (uint256, uint256) {
        return (
            _collections[_collectionId].tournamentEarningShare1e7,
            _collections[_collectionId].otherEarningShare1e7
        );
    }

    function getCollectionExists(uint256 _collectionId) external view returns (bool) {
        return _collections[_collectionId].exists;
    }

    function getMintedTokensOfCollection(uint256 _collectionId) external view returns (uint24) {
        return _collections[_collectionId].invocations;
    }

    /**
     * @notice Creates a new collection.
     * @dev Restricted to platform manager.
     */
    function createCollection(
        CreateCollection memory data
    ) external whenNotPaused onlyPlatformManager returns (uint256) {
        // Validate the data
        if (data.athleteSecondarySalesBPS + data.fantiumSecondarySalesBPS > 10_000) {
            revert InvalidCollection(CollectionErrorReason.INVALID_BPS_SUM);
        }

        if (data.maxInvocations >= 10_000) {
            revert InvalidCollection(CollectionErrorReason.INVALID_MAX_INVOCATIONS);
        }

        if (data.athletePrimarySalesBPS > 10_000) {
            revert InvalidCollection(CollectionErrorReason.INVALID_PRIMARY_SALES_BPS);
        }

        if (nextCollectionId >= 1_000_000) {
            revert InvalidCollection(CollectionErrorReason.MAX_COLLECTIONS_REACHED);
        }

        if (data.tournamentEarningShare1e7 > 1e7) {
            revert InvalidCollection(CollectionErrorReason.INVALID_TOURNAMENT_EARNING_SHARE);
        }

        if (data.otherEarningShare1e7 > 1e7) {
            revert InvalidCollection(CollectionErrorReason.INVALID_OTHER_EARNING_SHARE);
        }

        if (data.athleteAddress == address(0)) {
            revert InvalidCollection(CollectionErrorReason.INVALID_ATHLETE_ADDRESS);
        }

        if (data.fantiumSalesAddress == address(0)) {
            revert InvalidCollection(CollectionErrorReason.INVALID_FANTIUM_SALES_ADDRESS);
        }

        uint256 collectionId = nextCollectionId++;
        Collection memory collection = Collection({
            athleteAddress: data.athleteAddress,
            athletePrimarySalesBPS: data.athletePrimarySalesBPS,
            athleteSecondarySalesBPS: data.athleteSecondarySalesBPS,
            exists: true,
            fantiumSalesAddress: data.fantiumSalesAddress,
            fantiumSecondarySalesBPS: data.fantiumSecondarySalesBPS,
            invocations: 0,
            isMintable: false,
            isPaused: true,
            launchTimestamp: data.launchTimestamp,
            maxInvocations: data.maxInvocations,
            otherEarningShare1e7: data.otherEarningShare1e7,
            price: data.price,
            tournamentEarningShare1e7: data.tournamentEarningShare1e7
        });
        _collections[collectionId] = collection;

        return collectionId;
    }

    function updateCollection(
        uint256 collectionId,
        UpdateCollection memory data
    ) external onlyValidCollectionId(collectionId) whenNotPaused onlyPlatformManager {
        if (data.price == 0) {
            revert InvalidCollection(CollectionErrorReason.INVALID_PRICE);
        }

        if (data.tournamentEarningShare1e7 > 1e7) {
            revert InvalidCollection(CollectionErrorReason.INVALID_TOURNAMENT_EARNING_SHARE);
        }

        if (data.otherEarningShare1e7 > 1e7) {
            revert InvalidCollection(CollectionErrorReason.INVALID_OTHER_EARNING_SHARE);
        }

        if (data.maxInvocations >= 10_000) {
            revert InvalidCollection(CollectionErrorReason.INVALID_MAX_INVOCATIONS);
        }

        if (data.fantiumSalesAddress == address(0)) {
            revert InvalidCollection(CollectionErrorReason.INVALID_FANTIUM_SALES_ADDRESS);
        }

        if (data.athleteSecondarySalesBPS + data.fantiumSecondarySalesBPS > 10_000) {
            revert InvalidCollection(CollectionErrorReason.INVALID_SECONDARY_SALES_BPS);
        }

        Collection memory existing = _collections[collectionId];
        existing.fantiumSecondarySalesBPS = data.fantiumSecondarySalesBPS;
        existing.maxInvocations = data.maxInvocations;
        existing.price = data.price;
        existing.tournamentEarningShare1e7 = data.tournamentEarningShare1e7;
        existing.otherEarningShare1e7 = data.otherEarningShare1e7;
        _collections[collectionId] = existing;
    }

    /**
     * @notice Toggles isMintingPaused state of collection `_collectionId`.
     */
    function toggleCollectionPaused(
        uint256 collectionId
    ) external onlyValidCollectionId(collectionId) onlyAthlete(collectionId) {
        _collections[collectionId].isPaused = !_collections[collectionId].isPaused;
    }

    /**
     * @notice Toggles isMintingPaused state of collection `_collectionId`.
     */
    function toggleCollectionMintable(
        uint256 collectionId
    ) external onlyValidCollectionId(collectionId) onlyAthlete(collectionId) {
        _collections[collectionId].isMintable = !_collections[collectionId].isMintable;
    }

    function updateCollectionAthleteAddress(
        uint256 collectionId,
        address payable athleteAddress
    ) external onlyValidCollectionId(collectionId) onlyPlatformManager {
        if (athleteAddress == address(0)) {
            revert InvalidCollection(CollectionErrorReason.INVALID_ATHLETE_ADDRESS);
        }

        _collections[collectionId].athleteAddress = athleteAddress;
    }

    /**
     * @notice Updates athlete primary market royalties for collection
     * `_collectionId` to be `_primaryMarketRoyalty` percent.
     * This DOES NOT include the primary market royalty percentages collected
     * by FANtium; this is only the total percentage of royalties that will
     * be split to athlete.
     * @param collectionId collection ID.
     * @param primaryMarketRoyalty Percent of primary sales revenue that will
     * be sent to the athlete. This must be less than
     * or equal to 100 percent.
     */
    function updateCollectionAthletePrimaryMarketRoyaltyBPS(
        uint256 collectionId,
        uint256 primaryMarketRoyalty
    ) external onlyValidCollectionId(collectionId) onlyPlatformManager {
        require(primaryMarketRoyalty <= 10000, "Max of 100%");
        _collections[collectionId].athletePrimarySalesBPS = primaryMarketRoyalty;
    }

    /**
     * @notice Updates athlete secondary market royalties for collection
     * `_collectionId` to be `_secondMarketRoyalty` percent.
     * This DOES NOT include the secondary market royalty percentages collected
     * by FANtium; this is only the total percentage of royalties that will
     * be split to athlete.
     * @param collectionId collection ID.
     * @param secondMarketRoyalty Percent of secondary sales revenue that will
     * be sent to the athlete. This must be less than
     * or equal to 95 percent.
     */
    function updateCollectionAthleteSecondaryMarketRoyaltyBPS(
        uint256 collectionId,
        uint256 secondMarketRoyalty
    ) external onlyValidCollectionId(collectionId) onlyPlatformManager {
        if (secondMarketRoyalty + _collections[collectionId].fantiumSecondarySalesBPS > 10000) {
            revert InvalidCollection(CollectionErrorReason.INVALID_SECONDARY_SALES_BPS);
        }

        _collections[collectionId].athleteSecondarySalesBPS = secondMarketRoyalty;
    }

    /**
     * @notice Updates the launch timestamp of collection `_collectionId` to be
     * `_launchTimestamp`.
     */
    function updateCollectionLaunchTimestamp(
        uint256 _collectionId,
        uint256 _launchTimestamp
    ) external onlyValidCollectionId(_collectionId) onlyPlatformManager {
        _collections[_collectionId].launchTimestamp = _launchTimestamp;
        emit CollectionUpdated(_collectionId, FIELD_COLLECTION_LAUNCH_TIMESTAMP);
    }

    /*///////////////////////////////////////////////////////////////
                        PLATFORM FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setERC20PaymentToken(address _erc20PaymentToken) external onlyPlatformManager {
        erc20PaymentToken = _erc20PaymentToken;
    }

    // ========================================================================
    // Claiming functions
    // ========================================================================
    /**
     * @notice upgrade token version to new version in case of claim event
     */
    function upgradeTokenVersion(uint256 _tokenId) external whenNotPaused onlyValidTokenId(_tokenId) returns (bool) {
        // only claim contract can call this function
        require(claimContract != address(0), "Claim contract address is not set");

        require(claimContract == msg.sender, "Only claim contract can call this function");

        (uint256 _collectionId, uint256 _versionId, uint256 _tokenNr) = TokenVersionUtil.getTokenInfo(_tokenId);
        require(_collections[_collectionId].exists, "Collection does not exist");
        address tokenOwner = ownerOf(_tokenId);

        // burn old token
        _burn(_tokenId);
        _versionId++;

        require(_versionId < 100, "Version id cannot be greater than 99");

        uint256 newTokenId = TokenVersionUtil.createTokenId(_collectionId, _versionId, _tokenNr);
        // mint new token with new version
        _mint(tokenOwner, newTokenId);
        emit Mint(tokenOwner, newTokenId);
        if (ownerOf(newTokenId) == tokenOwner) {
            return true;
        } else {
            return false;
        }
    }

    // ========================================================================
    // Royalty functions
    // ========================================================================
    /**
     * @notice Gets royalty Basis Points (BPS) for token ID `_tokenId`.
     * This conforms to the IManifold interface designated in the Royalty
     * Registry's RoyaltyEngineV1.sol contract.
     * ref: https://github.com/manifoldxyz/royalty-registry-solidity
     * @param _tokenId Token ID to be queried.
     * @return recipients Array of royalty payment recipients
     * @return bps Array of Basis Points (BPS) allocated to each recipient,
     * aligned by index.
     * @dev reverts if invalid _tokenId
     * @dev only returns recipients that have a non-zero BPS allocation
     */
    function getRoyalties(
        uint256 _tokenId
    ) external view onlyValidTokenId(_tokenId) returns (address payable[] memory recipients, uint256[] memory bps) {
        // initialize arrays with maximum potential length
        recipients = new address payable[](2);
        bps = new uint256[](2);

        uint256 collectionId = _tokenId / ONE_MILLION;

        Collection storage collection = _collections[collectionId];
        // load values into memory
        uint256 athleteBPS = collection.athleteSecondarySalesBPS;
        uint256 fantiumBPS = collection.fantiumSecondarySalesBPS;
        // populate arrays
        uint256 payeeCount;
        if (athleteBPS > 0) {
            recipients[payeeCount] = collection.athleteAddress;
            bps[payeeCount++] = athleteBPS;
        }
        if (fantiumBPS > 0) {
            recipients[payeeCount] = collection.fantiumSalesAddress;
            bps[payeeCount++] = fantiumBPS;
        }

        return (recipients, bps);
    }
}
