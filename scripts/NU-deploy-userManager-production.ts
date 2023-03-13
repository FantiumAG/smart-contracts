import { writeFileSync } from "fs";
import { ethers, upgrades } from "hardhat";
import { join } from "path";

async function main() {

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  const FantiumUserManager = await ethers.getContractFactory("FantiumUserManager");
  const userManagerContract = await upgrades.deployProxy(FantiumUserManager, [deployer.address,'0x0000000000000000000000000000000000000000','0x0000000000000000000000000000000000000000'], { initializer: 'initialize', kind: 'uups'})
  await userManagerContract.deployed();

  // vault: 0x77C0B68aD8e5f07fE7C596512496262bDa5f0598
  console.log("FantiumUserManager deployed to:", userManagerContract.address);

  const data = {
    "proxy": userManagerContract.address,
    "implementation": await upgrades.erc1967.getImplementationAddress(userManagerContract.address),
  }
  writeFileSync(join(__dirname, './addresses/userManager.json'), JSON.stringify(data), {
    flag: 'w',
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
