// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import { IERC20MetadataUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script } from "forge-std/Script.sol";
import { FANtiumClaimingV2 } from "src/FANtiumClaimingV2.sol";
import { FANtiumMarketplaceV1 } from "src/FANtiumMarketplaceV1.sol";
import { FANtiumNFTV8 } from "src/FANtiumNFTV8.sol";
import { FANtiumTokenV1 } from "src/FANtiumTokenV1.sol";
import { FANtiumUserManagerV3 } from "src/FANtiumUserManagerV3.sol";
import { FootballTokenV1 } from "src/FootballTokenV1.sol";
import { UnsafeUpgrades } from "src/upgrades/UnsafeUpgrades.sol";

/**
 * @notice Deploy a new instance of the contract to the testnet.
 */
contract DeployTestnet is Script {
    address public constant ADMIN = 0xF00D14B2bf0b37177b6e13374aB4F34902Eb94fC;
    address public constant BACKEND_SIGNER = 0xCAFE914D4886B50edD339eee2BdB5d2350fdC809;
    address public constant DEPLOYER = 0xC0DE5408A46402B7Bd13678A43318c64E2c31EAA;
    address public constant TREASURY = 0x780Ab57FE57AC5D74F27E225488dd7D5cc2B9acF;

    /**
     * @dev Gelato relayer for ERC2771
     * See https://docs.gelato.network/web3-services/relay/supported-networks#gelatorelay1balanceerc2771.sol
     */
    address public constant GELATO_RELAYER_ERC2771 = 0x70997970c59CFA74a39a1614D165A84609f564c7;
    /**
     * @dev USDC token on Polygon Amoy.
     * See Circle announcement: https://developers.circle.com/stablecoins/migrate-from-mumbai-to-amoy-testnet
     */
    address public constant USDC = 0x41E94Eb019C0762f9Bfcf9Fb1E58725BfB0e7582;
    IERC20 public constant PAYMENT_TOKEN = IERC20(USDC);

    function run() public {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        FANtiumNFTV8 fantiumNFT = FANtiumNFTV8(
            UnsafeUpgrades.deployUUPSProxy(
                address(new FANtiumNFTV8()), abi.encodeCall(FANtiumNFTV8.initialize, (ADMIN))
            )
        );

        FANtiumUserManagerV3 userManager = FANtiumUserManagerV3(
            UnsafeUpgrades.deployUUPSProxy(
                address(new FANtiumUserManagerV3()), abi.encodeCall(FANtiumUserManagerV3.initialize, (ADMIN))
            )
        );

        FANtiumClaimingV2 fantiumClaim = FANtiumClaimingV2(
            UnsafeUpgrades.deployUUPSProxy(
                address(new FANtiumClaimingV2()), abi.encodeCall(FANtiumClaimingV2.initialize, (ADMIN))
            )
        );

        // FANtiumTokenV1 fantiumToken =
        FANtiumTokenV1(
            UnsafeUpgrades.deployUUPSProxy(
                address(new FANtiumTokenV1()), abi.encodeCall(FANtiumTokenV1.initialize, (ADMIN))
            )
        );

        // FootballTokenV1 footballToken =
        FootballTokenV1(
            UnsafeUpgrades.deployUUPSProxy(
                address(new FootballTokenV1()), abi.encodeCall(FootballTokenV1.initialize, (ADMIN))
            )
        );

        // FANtiumMarketplaceV1
        FANtiumMarketplaceV1(
            UnsafeUpgrades.deployUUPSProxy(
                address(new FANtiumMarketplaceV1()),
                abi.encodeCall(FANtiumMarketplaceV1.initialize, (ADMIN, TREASURY, PAYMENT_TOKEN))
            )
        );

        vm.stopBroadcast();

        vm.startBroadcast(vm.envUint("ADMIN_PRIVATE_KEY"));
        // FANtiumNFTV6 setup
        fantiumNFT.setUserManager(userManager);
        fantiumNFT.setERC20PaymentToken(IERC20MetadataUpgradeable(USDC));

        fantiumNFT.grantRole(fantiumNFT.FORWARDER_ROLE(), GELATO_RELAYER_ERC2771);
        fantiumNFT.grantRole(fantiumNFT.SIGNER_ROLE(), BACKEND_SIGNER);
        fantiumNFT.grantRole(fantiumNFT.TOKEN_UPGRADER_ROLE(), address(fantiumClaim));

        // FANtiumUserManagerV3 setup
        userManager.setFANtiumNFT(fantiumNFT);
        userManager.grantRole(userManager.FORWARDER_ROLE(), GELATO_RELAYER_ERC2771);
        userManager.grantRole(userManager.KYC_MANAGER_ROLE(), BACKEND_SIGNER);
        userManager.grantRole(userManager.ALLOWLIST_MANAGER_ROLE(), BACKEND_SIGNER);

        // FANtiumClaimingV2 setup
        fantiumClaim.setFANtiumNFT(fantiumNFT);
        fantiumClaim.setUserManager(userManager);
        fantiumClaim.setGlobalPayoutToken(USDC);

        vm.stopBroadcast();
    }
}
