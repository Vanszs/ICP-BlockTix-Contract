const TestToken = artifacts.require("TestToken");

module.exports = async function (deployer) {
  const initialSupply = web3.utils.toWei('100000000', 'ether'); // Sesuaikan jumlah suplai awal
  await deployer.deploy(TestToken, initialSupply);
};
