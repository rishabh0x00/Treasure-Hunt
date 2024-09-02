const { ethers } = require("hardhat");

module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  console.log(`Network invoked is::: ==>  ${hre.network.name}`);
  const VRFV2PlusWrapperAddress = process.env.VRF_V2_PLUS_WRAPPER_ADDRESS;

  if (!VRFV2PlusWrapperAddress){
    console.warn(
      `Missing VRF_V2_PLUS_WRAPPER_ADDRESS in .env file`
    );
  }


  const REQUEST_CONFIRMATIONS_BLOCKS = 3;
  const GAME_DURATION = 60 * 60 * 24; // 1-day
  const INACTIVE_GAMES_WITHDRAW_TVL_INDEX = 5;

  const treasureHunt = await deploy("TreasureHunt", {
    from: deployer,
    args: [
      VRFV2PlusWrapperAddress,
      REQUEST_CONFIRMATIONS_BLOCKS,
      GAME_DURATION,
      INACTIVE_GAMES_WITHDRAW_TVL_INDEX,
    ],
    log: true,
    deterministicDeployment: true,
  });
};

module.exports.tags = ["TreasureHunt"];
