
## MotokoShinkai: Blockchain-Based Event Management System

MotokoShinkai is a decentralized event management system powered by blockchain technology. It provides secure and transparent solutions for creating, managing, and participating in events. Built with Solidity for smart contracts and React for the frontend, MotokoShinkai ensures seamless ticketing and event operations.

---

### **Features**
- **Event Management**: Create and manage events with detailed configurations (name, date, ticket price, capacity).
- **Secure Ticketing**: Tickets are issued on-chain, ensuring transparency and security.
- **Fixed Rate Conversion**: Simplified ETH-to-USD conversion with a static rate.
- **Blockchain Integration**: Utilizes Ethereum's Holesky testnet for deploying smart contracts.
- **Frontend Interface**: Intuitive React-based UI for event organizers and participants.

---

### **Tech Stack**
- **Smart Contracts**: Solidity
- **Blockchain**: EVM
- **Frontend**: React.js
- **Backend Integration**: Web3.js / Ethers.js
- **Tools**:
  - Truffle for contract deployment and testing
  - OpenZeppelin for secure smart contract standards
  - Chainlink (optional for price feeds)

---

### **Project Structure**
```
motokoshinkai/
├── contracts/         # Solidity smart contracts
├── migrations/        # Truffle migration scripts
├── test/              # Smart contract tests
├── client/            # React frontend
│   ├── public/        # Static files for frontend
│   ├── src/           # React components and logic
│   │   ├── components/ # UI components
│   │   ├── pages/      # Application pages
│   │   ├── services/   # Smart contract interactions
│   │   └── App.js      # Main application entry point
├── .env               # Environment variables
├── truffle-config.js  # Truffle network configuration
└── README.md          # Project documentation
```

---

### **Installation**

#### **1. Clone the Repository**
```bash
git clone https://github.com/Vanszs/ICP-Hackaton-Web.git
cd motokoshinkai
```

#### **2. Install Dependencies**
- Install Truffle globally:
  ```bash
  npm install -g truffle
  ```
- Install project dependencies:
  ```bash
  npm install
  ```

#### **3. Setup Environment Variables**
Create a `.env` file in the root directory with the following:
```plaintext
PRIVATE_KEY=your-private-key
HOLESKY_RPC_URL=https://rpc.holesky.ethdevops.io
```

#### **4. Compile and Deploy Contracts**
```bash
truffle compile
truffle migrate --network holesky
```

#### **5. Setup Frontend**
Navigate to the `client` directory:
```bash
cd client
npm install
npm start
```

---

### **Usage**
- Access the frontend at `http://localhost:3000`.
- Create events, manage tickets, and explore blockchain-based event solutions.

---

### **Smart Contract Details**
- **Contract Address**: `0xYourContractAddress`
- **Network**: Ethereum Holesky Testnet

---

### **Contributing**
Contributions are welcome! Feel free to fork the repository and submit a pull request.

---

### **License**
This project is licensed under the MIT License. See the LICENSE file for details.

---

### **Author**
- **Name**: Vanszs
- **GitHub**: [Vanszs](https://github.com/Vanszs)
