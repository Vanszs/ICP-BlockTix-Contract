const MotokoShinkai = artifacts.require("MotokoShinkai");

module.exports = async function (deployer, network, accounts) {
  await deployer.deploy(MotokoShinkai);
};
