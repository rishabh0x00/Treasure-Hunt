const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("TreasureHunt Multiple Win Conditions and Error Cases", function () {
  let deployer, player1, player2;
  let treasureHunt;
  let mockVRFV2PlusWrapper;
  const PARTICIPATION_FEE = ethers.parseEther("0.1");
  const REQUEST_CONFIRMATIONS_BLOCKS = 1;
  const GAME_DURATION = 60 * 60; // 1-hour
  const INACTIVE_GAMES_WITHDRAW_TVL_INDEX = 3;

  beforeEach(async function () {
    [deployer, player1, player2] = await ethers.getSigners();

    mockVRFV2PlusWrapper = await ethers.deployContract("MockVRFV2PlusWrapper");

    treasureHunt = await ethers.deployContract(
      "TreasureHuntMock",
      [
        mockVRFV2PlusWrapper.target,
        REQUEST_CONFIRMATIONS_BLOCKS,
        GAME_DURATION,
        INACTIVE_GAMES_WITHDRAW_TVL_INDEX,
        50, // Initial treasure position
      ],
      deployer
    );

    await mockVRFV2PlusWrapper.setTreasureHunt(treasureHunt.target);

    // Participate in the game
    await treasureHunt
      .connect(player1)
      .participate({ value: PARTICIPATION_FEE });
    await treasureHunt
      .connect(player2)
      .participate({ value: PARTICIPATION_FEE });
  });

  it("should allow a player to win by landing directly on the treasure position", async function () {
    const gameIndex = await treasureHunt.currentGameIndex();
    const initialGame = await treasureHunt.games(gameIndex);

    const treasurePosition = Number(initialGame.treasurePosition);

    let alicePosition = 50; // same as the treasure position

    await treasureHunt.setPlayerPosition(player1.address, alicePosition);

    const gameTVL = initialGame.tvl;
    const reward = (gameTVL * BigInt(9)) / BigInt(10);

    // Verify player1's position
    const alicePlayerState = await treasureHunt.players(
      gameIndex,
      player1.address
    );
    expect(alicePlayerState.position).to.be.equal(alicePosition);

    let moveDirection = 1; // Right direction

    const tx = await (
      await treasureHunt.connect(player1).play(moveDirection)
    ).wait();
    await expect(tx)
      .to.emit(treasureHunt, "GameWon")
      .withArgs(player1.address, reward, gameIndex);
  });

  it("should allow a player to win when treasure moves to their position (prime number)", async function () {
    const gameIndex = await treasureHunt.currentGameIndex();
    const initialGame = await treasureHunt.games(gameIndex);

    const treasurePosition = Number(initialGame.treasurePosition); // 50

    let alicePosition = 3; // Prime position

    await treasureHunt.setPlayerPosition(player1.address, alicePosition);

    const gameTVL = initialGame.tvl;
    const reward = (gameTVL * BigInt(9)) / BigInt(10);

    // Verify player1's position
    const alicePlayerState = await treasureHunt.players(
      gameIndex,
      player1.address
    );
    expect(alicePlayerState.position).to.be.equal(alicePosition);

    let moveDirection = 1; // Right direction

    const tx = await (
      await treasureHunt.connect(player1).play(moveDirection)
    ).wait();

    let request = await treasureHunt.request();
    let newTreasurePosition = request.newPosition;

    await treasureHunt.setTreasurePosition(newTreasurePosition);
    const tx1 = await (
      await treasureHunt.feedRandomWords(request.requestId, [43])
    ).wait();
    await expect(tx1)
      .to.emit(treasureHunt, "GameWon")
      .withArgs(player1.address, reward, gameIndex);
  });

  it("should allow a player to win when treasure moves to their position (multiple of 5)", async function () {
    const gameIndex = await treasureHunt.currentGameIndex();
    const initialGame = await treasureHunt.games(gameIndex);

    const treasurePosition = Number(initialGame.treasurePosition); // 50

    let alicePosition = 10; // Multiple of 5 position

    await treasureHunt.setPlayerPosition(player1.address, alicePosition);

    const gameTVL = initialGame.tvl;
    const reward = (gameTVL * BigInt(9)) / BigInt(10);

    // Verify player1's position
    const alicePlayerState = await treasureHunt.players(
      gameIndex,
      player1.address
    );
    expect(alicePlayerState.position).to.be.equal(alicePosition);

    let moveDirection = 1; // Right direction

    const tx = await (
      await treasureHunt.connect(player1).play(moveDirection)
    ).wait();

    let request = await treasureHunt.request();
    let newTreasurePosition = request.newPosition;

    await treasureHunt.setTreasurePosition(newTreasurePosition);
    const tx1 = await (
      await treasureHunt.feedRandomWords(request.requestId, [43])
    ).wait();
    await expect(tx1)
      .to.emit(treasureHunt, "GameWon")
      .withArgs(player1.address, reward, gameIndex);
  });

  it("should allow a player to win when treasure moves to their position (multiple of 5 and a Prime number)", async function () {
    const gameIndex = await treasureHunt.currentGameIndex();
    const initialGame = await treasureHunt.games(gameIndex);

    const treasurePosition = Number(initialGame.treasurePosition); // 50

    let alicePosition = 5; // Multiple of 5 and a prime number also

    await treasureHunt.setPlayerPosition(player1.address, alicePosition);

    const gameTVL = initialGame.tvl;
    const reward = (gameTVL * BigInt(9)) / BigInt(10);

    // Verify player1's position
    const alicePlayerState = await treasureHunt.players(
      gameIndex,
      player1.address
    );
    expect(alicePlayerState.position).to.be.equal(alicePosition);

    let moveDirection = 1; // Right direction

    const tx = await (
      await treasureHunt.connect(player1).play(moveDirection)
    ).wait();

    let request = await treasureHunt.request();
    let newTreasurePosition = request.newPosition;

    await treasureHunt.setTreasurePosition(newTreasurePosition);
    const tx1 = await (
      await treasureHunt.feedRandomWords(request.requestId, [43])
    ).wait();
    await expect(tx1)
      .to.emit(treasureHunt, "GameWon")
      .withArgs(player1.address, reward, gameIndex);
  });

  it("should revert with UserAlreadyRegistered when a player tries to participate twice", async function () {
    await expect(
      treasureHunt.connect(player1).participate({ value: PARTICIPATION_FEE })
    )
      .to.be.revertedWithCustomError(treasureHunt, "UserAlreadyRegistered")
      .withArgs(player1.address);
  });

  it("should revert with InvalidParticipationFee when incorrect fee is sent", async function () {
    const incorrectFee = ethers.parseEther("0.05");
    await expect(
      treasureHunt.connect(deployer).participate({ value: incorrectFee })
    ).to.be.revertedWithCustomError(treasureHunt, "InvalidParticipationFee");
  });

  it("should revert with GameCannotBeExpired when trying to expire a game too early", async function () {
    const currentGameIndex = await treasureHunt.currentGameIndex();
    await expect(treasureHunt.expireCurrentGame())
      .to.be.revertedWithCustomError(treasureHunt, "GameCannotBeExpired")
      .withArgs(currentGameIndex);
  });

  it("should revert with ZeroAmountToWithdraw when non-participant tries to withdraw", async function () {
    const currentGameIndex = await treasureHunt.currentGameIndex();

    // Fast-forward time to make the game expirable
    await ethers.provider.send("evm_increaseTime", [GAME_DURATION + 1]);
    await ethers.provider.send("evm_mine");

    await treasureHunt.expireCurrentGame();

    await expect(
      treasureHunt.connect(deployer).withdrawFunds(currentGameIndex)
    ).to.be.revertedWithCustomError(treasureHunt, "ZeroAmountToWithdraw");
  });

  it("should revert with OnlyDeployerCanCall when non-deployer tries to withdraw inactive games TVL", async function () {
    await expect(
      treasureHunt.connect(player1).withdrawInactiveGamesTVL()
    ).to.be.revertedWithCustomError(treasureHunt, "OnlyDeployerCanCall");
  });

  it("should revert with NotEnoughGamesPlayedYetToWithdrawTVL when trying to withdraw TVL too early", async function () {
    const currentGameIndex = await treasureHunt.currentGameIndex();

    // Fast-forward time to make the game expirable
    await ethers.provider.send("evm_increaseTime", [GAME_DURATION + 1]);
    await ethers.provider.send("evm_mine");

    await treasureHunt.expireCurrentGame();

    await expect(treasureHunt.connect(deployer).withdrawInactiveGamesTVL())
      .to.be.revertedWithCustomError(
        treasureHunt,
        "NotEnoughGamesPlayedYetToWithdrawTVL"
      )
      .withArgs(currentGameIndex + BigInt(1));
  });
});
