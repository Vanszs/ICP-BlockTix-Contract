const Loketh = artifacts.require("MotokoShinkai");
module.exports = async function (deployer, network, accounts) {
  console.log(`Deploying to network: ${network}`);

  // Jika ada alamat atau konfigurasi khusus berdasarkan jaringan
  if (network === "holesky") {
    console.log("Using Holesky-specific settings...");
    // Tambahkan logika khusus untuk Holesky jika diperlukan
  }

  // Deploy kontrak Loketh
  await deployer.deploy(Loketh);

  const lokethInstance = await Loketh.deployed();
  console.log("Loketh deployed at address:", lokethInstance.address);
};
