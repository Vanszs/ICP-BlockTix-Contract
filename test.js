const Web3 = require('web3');
require('dotenv').config();

// Gunakan URL RPC dari file .env
const rpcUrl = process.env.HOLESKY_RPC_URL || "https://rpc.holesky.ethpandaops.io";

// Inisialisasi koneksi Web3
const web3 = new Web3(rpcUrl);

// Cek koneksi ke jaringan
async function testConnection() {
  try {
    const networkId = await web3.eth.net.getId();
    console.log(`Connected to network ID: ${networkId}`);

    const latestBlock = await web3.eth.getBlockNumber();
    console.log(`Latest block number: ${latestBlock}`);

    const accounts = await web3.eth.getAccounts();
    console.log(`Available accounts: ${accounts}`);
  } catch (error) {
    console.error("Error connecting to Holesky:", error);
  }
}

testConnection();
