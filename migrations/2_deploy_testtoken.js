const TestToken = artifacts.require("TestToken");

module.exports = async function (deployer) {
  await deployer.deploy(TestToken);
};
