const MotokoShinkai = artifacts.require("MotokoShinkai");
const TestToken = artifacts.require("TestToken");

module.exports = async function (deployer, network, accounts) {
  const testToken = await TestToken.deployed();
  await deployer.deploy(MotokoShinkai, testToken.address);
};
