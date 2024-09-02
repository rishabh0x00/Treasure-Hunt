# 🏴‍☠️ TreasureHunt

---

TreasureHunt is an on-chain game where players participate in a treasure hunt on a 10x10 grid. The game leverages Chainlink VRF for verifiable randomness in treasure placement and movement.

## 🎮 Game Overview

- Players move on a 10x10 grid (100 positions)
- The treasure's position is randomly determined
- Players aim to land on the treasure's position to win
- The treasure moves based on specific conditions

## 🌟 Key Features

- Chainlink VRF integration for randomness
- Player participation with a fee
- Dynamic treasure movement
- Automatic game expiry and reset
- Withdrawal mechanism for inactive games

## 📏 Game Mechanics

1. **Participation**: Players join by paying a participation fee (0.1 ETH).
2. **Movement**: Players can move Left, Right, Top, or Bottom.
3. **Treasure Movement**:
   - If a player lands on a multiple of 5, the treasure moves to a random adjacent position.
   - If a player lands on a prime number, the treasure moves to a random position on the grid.
4. **Winning**: A player wins by landing on the treasure's position.
5. **Rewards**: The winner receives 90% of the total balance as a reward.

## 🔑 Key Functions

- `participate()`: Join the game by paying the participation fee.
- `play(Directions move)`: Make a move in the specified direction.
- `expireCurrentGame()`: End the current game if it has exceeded the time limit.
- `withdrawInactiveGamesTVL()`: Withdraw TVL from a series of inactive games (only by contract deployer).
- `withdrawFunds(uint256 gameIndex)`: Withdraw participation fee after game expiry.

### 💰 withdrawInactiveGamesTVL

This function plays a crucial role in managing the Total Value Locked (TVL) in the contract, especially in scenarios where games have been inactive for an extended period.

#### 🎯 Purpose:

- To withdraw the accumulated TVL from a series of inactive games.
- To prevent indefinite lock-up of funds in case of consecutive games with no participants.

#### ⚙️ Mechanism:

1. When a game is won, 90% of the TVL is distributed to the winner, and 10% is moved to the next game.
2. If subsequent games have no participants, this 10% TVL accumulates over time.
3. The `withdrawInactiveGamesTVL` function allows the contract deployer to withdraw this accumulated TVL after a predefined number of inactive games.

#### 🔍 Key Points:

- Only the contract deployer can call this function.
- It checks for a series of inactive games (defined by `MIN_IDLE_GAMES`).
- All games in the checked series must be inactive (no winner) and have non-zero TVL.
- If conditions are met, the accumulated TVL is withdrawn to the caller (deployer).
- This mechanism ensures that funds don't remain locked indefinitely in case of prolonged inactivity.

#### 🛠 Usage:

This function should be used judiciously to maintain the economic balance of the game while ensuring that funds are not permanently trapped in the contract due to lack of participation.

## 📢 Events

- `PlayerRegistered`: Emitted when a player joins the game.
- `PlayerMoved`: Emitted when a player makes a move.
- `TreasureMoved`: Emitted when the treasure changes position.
- `GameWon`: Emitted when a player wins the game.
- `GameStarted`: Emitted when a new game round begins.
- `GameExpired`: Emitted when a game expires without a winner.

## 🚀 Setup and Deployment

1. Ensure you have the Chainlink VRF contracts and dependencies set up.
2. Set up your environment variables:
   - Rename `.env.example` to `.env`
   - Fill in the required values in the `.env` file
3. Deploy the contract with the following parameters:
   - VRF Wrapper address
   - Request confirmation blocks
   - Game duration
   - Minimum idle games for TVL withdrawal

### 🔐 Environment Variables

The project uses a `.env` file to manage sensitive and configuration information. Follow these steps to set it up:

1. Locate the `.env.example` file in the project root.
2. Create a copy of this file and rename it to `.env`.
3. Open the `.env` file and fill in the following variables:

```
ALCHEMY_NODE_API_KEY=your_alchemy_api_key
DEPLOYER_PVT_KEY=your_private_key
ETHERSCAN_API_KEY=your_etherscan_api_key
VRF_V2_PLUS_WRAPPER_ADDRESS=0x195f15F2d49d693cE265b4fB0fdDbE15b1850Cc1
```

- `ALCHEMY_NODE_API_KEY`: Your Alchemy API key for accessing Ethereum nodes
- `DEPLOYER_PVT_KEY`: The private key of the account deploying the contract
- `ETHERSCAN_API_KEY`: Your Etherscan API key for contract verification
- `VRF_V2_PLUS_WRAPPER_ADDRESS`: The address of the Chainlink VRF V2 Plus Wrapper contract (pre-filled for Sepolia testnet)

**Important:**

- Never commit your `.env` file to version control.
- Keep your private keys and API keys secure.
- The `VRF_V2_PLUS_WRAPPER_ADDRESS` is pre-filled for the Sepolia testnet. Adjust this if deploying to a different network.

## 🧪 Running Tests

To run the test suite for TreasureHunt, follow these steps:

1. Ensure you have set up your environment variables as described in the "Environment Variables" section above.

2. Open a terminal and navigate to the project's root directory.

3. Run the following command:

   ```
   npm test
   ```

   This command will execute all the tests in the test suite.

4. The test results will be displayed in the terminal, showing which tests passed and which (if any) failed.

Make sure you have all the necessary dependencies installed before running the tests. If you encounter any issues, double-check your environment setup and ensure all required packages are installed by running `npm install`.

## 🛡️ Security Considerations

- The contract uses Chainlink VRF for randomness, ensuring fair and verifiable random number generation.
- Game expiry and TVL withdrawal mechanisms are in place to handle edge cases.
- Proper access control is implemented for admin functions.

## 🔮 Future Improvements

- Implement a frontend for easier interaction with the game.
- Add more complex game mechanics or obstacles.
- Introduce a token system for rewards and governance.
- The game currently relies entirely on Chainlink VRF for randomness.
- In the event that Chainlink VRF becomes unavailable or impractical, the contract will be designed to allow for replacement with an alternative source of randomness in future iterations.

## 🏗️ Design Principles

The TreasureHunt smart contract was developed with the following design principles in mind:

1. **Decentralized Randomness**:

   - Utilizes Chainlink VRF (Verifiable Random Function) for secure and verifiable random number generation.
   - Implements the direct funding mechanism for Chainlink VRF to ensure efficient and cost-effective random number requests.

2. **Simplicity and Security**:

   - Handles only one random number request at a time to avoid complexity and potential malicious exploitation.
   - Follows best practices suggested by Chainlink for VRF integration, as outlined in their [documentation](https://docs.chain.link/vrf/v2-5/best-practices).

3. **Full Decentralization**:
   - No ownership model is implemented, making the contract completely decentralized.
   - This design choice eliminates single points of failure and ensures fair gameplay for all participants.

### 🌐 Sepolia Testnet Deployment

The TreasureHunt contract has been deployed on the Sepolia testnet. You can interact with or verify the contract at the following address:

**Contract Address**: `0x22c9a2433DC380175335B749fc333434e4cfbca6`

**Etherscan Link**: [https://sepolia.etherscan.io/address/0x22c9a2433DC380175335B749fc333434e4cfbca6#code](https://sepolia.etherscan.io/address/0x22c9a2433DC380175335B749fc333434e4cfbca6#code)

You can use this deployment to:

- Interact with the contract through Etherscan's "Read Contract" and "Write Contract" interfaces
- Monitor events and transactions related to the game

Remember to connect your wallet to the Sepolia testnet when interacting with this contract.

---
