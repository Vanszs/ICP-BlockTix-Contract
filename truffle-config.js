require('dotenv').config();
const HDWalletProvider = require('@truffle/hdwallet-provider');

module.exports = {
  networks: {
    // Jaringan lokal untuk pengembangan
    dev: {
      host: "127.0.0.1",     // Localhost
      port: 8545,            // Port default Ganache CLI
      network_id: "*",       // Menerima koneksi dari jaringan manapun
    },
    // Jaringan Holesky
    holesky: {
      provider: () => new HDWalletProvider({
        privateKeys: [process.env.PRIVATE_KEY],
        providerOrUrl: process.env.HOLESKY_RPC_URL,
      }),
      network_id: 17000,       // Network ID untuk Holesky
      gas: 8000000,            // Batas gas
      gasPrice: 2000000000,    // Harga gas (2 Gwei)
      confirmations: 2,        // Jumlah konfirmasi blok
      timeoutBlocks: 200,      // Batas waktu untuk blok
      skipDryRun: true,        // Lewati dry run sebelum deploy
    },
    // Jaringan Bitfinity Testnet
    bit: {
      provider: () => new HDWalletProvider({
        privateKeys: [process.env.PRIVATE_KEY],
        providerOrUrl: "https://testnet.bitfinity.network",
      }),
      network_id: 355113,      // Network ID untuk Bitfinity Testnet
      gas: 8000000,            // Batas gas
      gasPrice: 2000000000,    // Harga gas (2 Gwei)
      confirmations: 2,        // Jumlah konfirmasi blok
      timeoutBlocks: 200,      // Batas waktu untuk blok
      skipDryRun: true,        // Lewati dry run sebelum deploy
    },
  },
  compilers: {
    solc: {
      version: "0.8.0",        // Versi compiler Solidity
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
    },
  },
};
