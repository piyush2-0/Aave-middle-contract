const hre = require("hardhat");

async function main() {

  // We get the AaveERC20 contract to deploy
  const AaveERC20MiddleContract = await hre.ethers.getContractFactory("AaveERC20MiddleContract");
  const aaveERC20MiddleContract = await AaveERC20MiddleContract.deploy();

  await aaveERC20MiddleContract.deployed();

  console.log("AaveERC20MiddleContract deployed to:", aaveERC20MiddleContract.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
