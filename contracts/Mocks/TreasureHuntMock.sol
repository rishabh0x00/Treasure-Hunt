// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.24;

import {VRFV2PlusWrapperConsumerBase} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFV2PlusWrapperConsumerBase.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
/**
 * @title TreasureHunt
 * @dev A game contract where players participate in a treasure hunt, with position moves and treasure location updates.
 */

contract TreasureHuntMock is VRFV2PlusWrapperConsumerBase {
    // Enum representing possible move directions
    enum Directions {
        Left,
        Right,
        Top,
        Bottom
    }

    enum TreasureMove {
        MultipleOfFive,
        PrimeNumber
    }

    struct Game {
        uint8 treasurePosition;
        bool treasureMoving; // players cannont play when treasure is moving
        uint40 startTime;
        address winner;
        uint256 tvl;
        uint256 playerCount;
    }

    struct Player {
        uint8 position;
        bool isActive;
    }

    struct Request {
        address player;
        uint8 newPosition;
        TreasureMove condition;
        bool newGame;
        uint256 requestId;
    }

    // Constants
    /* Bitmap of prime numbers from 0 to 99
     Each bit represents a number, 1 if prime, 0 if not
     100 bits, so we use a uint128
    */
    uint256 private constant _PRIME_BITMASK = 0x20208828828208a20a08a28ac;
    bytes private extraArgs;
    uint32 private constant CALLBACK_GAS_LIMIT = 100000;
    uint32 private constant _NUM_OF_RANDOM_WORDS = 1;
    uint16 private immutable _REQUEST_CONFIRMATIONS;

    // Public Variables
    uint256 public currentGameIndex; // Current game round index
    uint8 public constant GRID_SIZE = 100;
    uint256 public constant PARTICIPATION_FEE = 0.1 ether;
    uint256 public immutable GAME_DURATION;
    uint256 public immutable MIN_IDLE_GAMES;
    address public immutable DEPLOYER;
    //For testing purposes
    uint8 public latestPlayerPosition;
    mapping(uint256 gameIndex => Game game) public games;
    mapping(uint256 gameIndex => mapping(address userAddress => Player position)) public players;
    Request public request;

    // Events
    event PlayerRegistered(address indexed player, uint256 currentGameIndex);
    event PlayerMoved(address player, uint256 currentGameIndex, uint8 newPosition);
    event TreasureMoved(uint8 indexed newPosition, uint256 currentGameIndex);
    event GameWon(address indexed winner, uint256 prize, uint256 currentGameIndex);
    event GameStarted(uint256 indexed currentGameIndex, uint256 initialTVL, uint8 initialTreasurePosition);
    event GameExpired(uint256 indexed currentGameIndex);
    event FundsWithdrawn(address indexed user);
    event RequestSent(uint256 requestId);
    event RequestFulfilled(uint256 requestId, uint256[] randomWords);
    event Received(address indexed sender, uint256 amount);
    event InactiveGamesTVLWithdrawn(address indexed withdrawer, uint256 amount);

    // Custom Errors
    error UserAlreadyRegistered(address user);
    error WaitForNextTurn();
    error InvalidMove(Directions move, uint8 currentPosition);
    error GameNotExpired(uint256 currentGameIndex);
    error GameNotActive(uint256 currentGameIndex);
    error GameCannotBeExpired(uint256 currentGameIndex);
    error ZeroAmountToWithdraw();
    error CannotStartNewGame();
    error InvalidExpiry();
    error InvalidTurnDuration();
    error InvalidParticipationFee();
    error ErrorMovingTreasure();
    error RequestNotFound(uint256 requestId);
    error NoInactiveGameWithTVLToWithdraw();
    error NotEnoughGamesPlayedYetToWithdrawTVL(uint256 currentGameIndex);
    error NumberMustBeLessThanHundered();
    error OnlyDeployerCanCall();

    /**
     * @dev Constructor to initialize the contract with minimum turn duration and expiry duration.
     * @param _vrfV2PlusWrapper Address of chainlink vrfV2PlusWrapper contract on deployment chain
     * @param _requestConfirmation The number of block confirmations the VRF service will wait to respond.
     * @param _gameDuration Duration till the game lasts
     * @param _inactiveGamesWithdrawTVLIndex Index count for inactive games for withdrawal of accumulated TVL
     */
    constructor(
        address _vrfV2PlusWrapper,
        uint16 _requestConfirmation,
        uint256 _gameDuration,
        uint256 _inactiveGamesWithdrawTVLIndex,
        uint8 _initialTreasurePosition
    ) VRFV2PlusWrapperConsumerBase(_vrfV2PlusWrapper) {
        currentGameIndex++;
        games[currentGameIndex].startTime = uint40(block.timestamp);
        games[currentGameIndex].treasurePosition = _initialTreasurePosition;
        _REQUEST_CONFIRMATIONS = _requestConfirmation;
        GAME_DURATION = _gameDuration;
        MIN_IDLE_GAMES = _inactiveGamesWithdrawTVLIndex;
        DEPLOYER = msg.sender;
        emit GameStarted(currentGameIndex, games[currentGameIndex].tvl, _initialTreasurePosition);
        extraArgs = VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: true}));
    }

    // Modifiers

    /**
     * @dev Modifier to check if the game has expired.
     */
    modifier gameExpired(uint256 gameIndex) {
        if (gameIndex >= currentGameIndex) {
            revert GameNotExpired(currentGameIndex);
        }
        _;
    }

    // External functions

    /**
     * @dev Participate in the game by paying the participation fee.
     * @notice The participant must send Ether to join the game.
     * If the player has already registered for the current game round, the transaction will revert.
     * Emits a {PlayerRegistered} event.
     */
    function participate() external payable {
        if (msg.value != PARTICIPATION_FEE) {
            revert InvalidParticipationFee();
        }
        address participant = msg.sender;

        if (players[currentGameIndex][participant].isActive) {
            revert UserAlreadyRegistered(participant);
        }

        games[currentGameIndex].playerCount++;
        games[currentGameIndex].tvl += PARTICIPATION_FEE;
        players[currentGameIndex][participant].isActive = true;

        emit PlayerRegistered(participant, currentGameIndex);
    }

    /**
     * @dev Allows a player to make a move in the specified direction.
     * The player must wait for their turn before making a move.
     * Updates the player's position and checks if the move results in winning the game.
     * If the player wins, the game is ended; otherwise, the treasure's position is updated.
     *
     * Emits a {PlayerMoved} event when the player makes a move.
     *
     * @param move The direction in which the player wants to move. This should be one of the values from the `Directions` enum.
     */
    function play(Directions move) public payable {
        uint256 _currentGameIndex = currentGameIndex;
        Player memory _player = players[_currentGameIndex][msg.sender];
        require(_player.isActive, "INACTIVE player");
        Game memory _game = games[_currentGameIndex];
        require(!_game.treasureMoving, "Treasure is in movement");
        uint8 playerPosition = _player.position;
        uint8 treasurePosition = _game.treasurePosition;

        if (playerPosition == treasurePosition) {
            _endGameAndProcessFunds(_currentGameIndex, msg.sender);
        } else {
            uint8 newPosition = _newPosition(playerPosition, move, true);

            if (_isPrime(newPosition)) {
                request.condition = TreasureMove.PrimeNumber;
                request.player = msg.sender;
                request.newPosition = newPosition;
                _requestRandomWords(_currentGameIndex);
            } else if (newPosition % 5 == 0) {
                request.condition = TreasureMove.MultipleOfFive;
                request.player = msg.sender;
                request.newPosition = newPosition;

                _requestRandomWords(_currentGameIndex);
            } else {
                players[_currentGameIndex][msg.sender].position = newPosition;
                emit PlayerMoved(msg.sender, _currentGameIndex, newPosition);
                if (newPosition == treasurePosition) {
                    _endGameAndProcessFunds(_currentGameIndex, msg.sender);
                }
            }
        }
    }

    /**
     * @dev Expire the current game.
     *
     * Emits a {GameExpired} event.
     *
     * Reverts with:
     * - `GameCannotBeExpired` if the current time is less than the game's expiry time.
     */
    function expireCurrentGame() external {
        uint256 _currentGameIndex = currentGameIndex;
        Game memory game = games[_currentGameIndex];
        if (block.timestamp <= (game.startTime + GAME_DURATION)) {
            revert GameCannotBeExpired(_currentGameIndex);
        }

        games[_currentGameIndex + 1].tvl = game.tvl - (game.playerCount * PARTICIPATION_FEE); // Remaining 10% stays for the next round

        _startNewGame(_currentGameIndex);
        emit GameExpired(_currentGameIndex);
    }

    /// @notice Allows withdrawal of TVL from inactive games
    /// @dev This function checks for a series of inactive games and allows withdrawal of accumulated TVL
    function withdrawInactiveGamesTVL() external {
       
        if (msg.sender != DEPLOYER) {
            revert OnlyDeployerCanCall();
        }
        uint256 _currentGameIndex = currentGameIndex;

        // Check if there are enough games played to allow withdrawal
        if (_currentGameIndex < MIN_IDLE_GAMES) {
            revert NotEnoughGamesPlayedYetToWithdrawTVL(_currentGameIndex);
        }

        Game memory currentGame = games[_currentGameIndex];

        // Ensure the current game has expired
        if (block.timestamp <= currentGame.startTime + GAME_DURATION) {
            revert GameCannotBeExpired(_currentGameIndex);
        }

        uint256 startIndex = _currentGameIndex - MIN_IDLE_GAMES;

        // Iterate through the range and ensure all games are inactive with non-zero TVL
        for (uint256 i = startIndex; i <= _currentGameIndex; i++) {
            // If any game in the range is not inactive with non-zero TVL, revert immediately
            if (games[i].winner != address(0) || games[i].tvl == 0) {
                revert NoInactiveGameWithTVLToWithdraw();
            }
        }

        // Withdraw TVL of the current game to the caller
        uint256 withdrawableTVL = currentGame.tvl;
        payable(msg.sender).transfer(withdrawableTVL);
        _startNewGame(_currentGameIndex);

        emit InactiveGamesTVLWithdrawn(msg.sender, withdrawableTVL);
    }

    /**
     * @dev Withdraw participation funds after the game has expired.
     *
     * Requirements:
     * - The current game must be expired.
     * - The caller must have a non-zero participation fee for the expired game.
     *
     * Emits a {FundsWithdrawn} event.
     */
    function withdrawFunds(uint256 gameIndex) external gameExpired(gameIndex) {
        Player storage player = players[gameIndex][msg.sender];
        if (!player.isActive) {
            revert ZeroAmountToWithdraw();
        }
        player.isActive = false;
        games[gameIndex].playerCount--;
        games[gameIndex].tvl -= PARTICIPATION_FEE;
        address payable receiver = payable(msg.sender);
        receiver.transfer(PARTICIPATION_FEE);

        emit FundsWithdrawn(receiver);
    }

    // Internal Functions

    function _isPrime(uint8 number) internal pure returns (bool) {
        if (number >= GRID_SIZE) {
            revert NumberMustBeLessThanHundered();
        }
        return (_PRIME_BITMASK & (1 << number)) != 0;
    }

    /**
     * @notice Handles the fulfillment of random words from the VRF (Verifiable Random Function) request.
     * @dev This function is called by the VRFCoordinator when it receives the VRF response. It updates
     *      the request status to fulfilled, stores the received random words, and emits an event.
     *      Depending on the value of `resetTreasurePosition`, it either resets or moves the treasure's position.
     * @param _requestId The unique identifier of the VRF request.
     * @param _randomWords An array of random words provided by the VRF Coordinator.
     */
    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        uint256 _currentGameIndex = currentGameIndex;
        games[_currentGameIndex].treasureMoving = false;
        if (request.requestId != _requestId) {
            revert RequestNotFound(_requestId);
        }
        if (request.newGame) {
            _resetTreasurePosition(_randomWords[0]);
        } else {
            _moveTreasure(_randomWords[0], true);

            if (request.newPosition == games[_currentGameIndex].treasurePosition) {
                _endGameAndProcessFunds(_currentGameIndex, request.player);
            }
        }
        emit RequestFulfilled(_requestId, _randomWords);
    }

    // For testing purpose only
    function feedRandomWords(uint256 _requestId, uint256[] memory _randomWords) external {
        fulfillRandomWords(_requestId, _randomWords);
    }

    function setPlayerPosition(address _player, uint8 _position) external {
        players[currentGameIndex][_player].position = _position;
        latestPlayerPosition = _position;
    }

    function setTreasurePosition(uint8 _position) external {
        games[currentGameIndex].treasurePosition = _position;
    }

    /**
     * @dev Moves the treasure based on the player's new position.
     * The treasure's movement is determined by specific conditions:
     * - If the player's current position is divisible by 5, the treasure will move to a random adjacent position.
     * - If the treasure's current position is a prime number, it will move to a random position on the grid.
     * Emits a `TreasureMoved` event after the treasure has moved.
     */
    function _moveTreasure(uint256 randomWord, bool isTesting) internal {
        if (isTesting) {} else {
            if (request.condition == TreasureMove.MultipleOfFive) {
                _moveToRandomAdjacentPosition(randomWord);
            } else if (request.condition == TreasureMove.PrimeNumber) {
                _moveToRandomPosition(randomWord);
            }
        }
    }

    /**
     * @dev Handle the winning condition, transfer the reward to the winner, and reset the game.
     * This function is triggered when a player lands on the treasure's position.
     * It performs the following actions:
     * - Sets the current player as the winner for the game.
     * - Transfers 90% of the total balance as the reward to the winner.
     * - Emits a `GameWon` event to announce the winner and the reward.
     * - Calls `_resetGame` to start a new game round.
     */
    function _endGameAndProcessFunds(uint256 _currentGameIndex, address _winner) internal {
        games[_currentGameIndex].winner = _winner;
        uint256 reward = (games[_currentGameIndex].tvl * 9) / 10;
        payable(_winner).transfer(reward);
        games[_currentGameIndex + 1].tvl = address(this).balance; // Remaining 10% stays for the next round
        emit GameWon(_winner, reward, _currentGameIndex);
        _startNewGame(_currentGameIndex);
    }

    /**
     * @dev Start a new game round.
     * Increments the game index, sets the game as active, and moves the treasure to a new random position.
     * The expiry time for the new game round is also set based on the expiry duration.
     * Emits a `GameStarted` event with the new game index.
     */
    function _startNewGame(uint256 _currentGameIndex) internal {
        currentGameIndex++;
        games[currentGameIndex].startTime = uint40(block.timestamp);

        request.newGame = true;
        _requestRandomWords(_currentGameIndex);
    }

    /**
     * @dev Moves the treasure to a random position on the grid.
     * Ensures that the new position is neither the current position of the treasure
     * nor the current position of the player.
     */
    function _moveToRandomPosition(uint256 randomWord) internal {
        uint8 newTreasurePosition = uint8(randomWord % GRID_SIZE);
        games[currentGameIndex].treasurePosition = newTreasurePosition;
        emit TreasureMoved(newTreasurePosition, currentGameIndex);
    }

    /**
     * @dev Moves the treasure to a random adjacent position.
     * @notice This function is internal and should only be called from within the contract.
     */
    function _moveToRandomAdjacentPosition(uint256 randomWord) internal {
        uint8 position = games[currentGameIndex].treasurePosition;
        uint8[4] memory possiblePositions;
        uint8 count = 0;

        uint8 y = position / 10; // y axis of the board
        uint8 x = position % 10; // x axis of the board

        if (x != 0) {
            possiblePositions[count++] = position - 1; // valid left
        }

        if (y != 0) {
            possiblePositions[count++] = position - 10; // valid top
        }

        if (x != 9) {
            possiblePositions[count++] = position + 1; // valid right
        }

        if (y != 9) {
            possiblePositions[count++] = position + 10; // valid bottom
        }

        require(count > 0, "No valid moves");
        uint8 newTreasurePosition = possiblePositions[randomWord % count];

        games[currentGameIndex].treasurePosition = newTreasurePosition;
        emit TreasureMoved(newTreasurePosition, currentGameIndex);
    }

    /**
     * @notice Internal function to request random words from the randomness oracle.
     * @dev This function requests a specified number of random words from the randomness oracle.
     * @return requestId The ID of the randomness request, which can be used to track and manage the request status.
     */
    function _requestRandomWords(uint256 _currentGameIndex) internal returns (uint256 requestId) {
        games[_currentGameIndex].treasureMoving = true;

        (requestId,) =
            requestRandomnessPayInNative(CALLBACK_GAS_LIMIT, _REQUEST_CONFIRMATIONS, _NUM_OF_RANDOM_WORDS, extraArgs);
        request.requestId = requestId;
        emit RequestSent(requestId);
    }

    /**
     * @notice Resets the position of the treasure in the current game.
     * @dev This function sets the treasure position based on a random word and reactivates the game.
     * @param randomWord A random uint256 value used to determine the new treasure position.
     * The treasure position is set as the modulo of this randomWord with GRID_SIZE.
     * The function also emits a GameStarted event indicating the game has started with the new settings.
     */
    function _resetTreasurePosition(uint256 randomWord) internal {
        request.newGame = false;
        uint8 initialTreasurePosition = uint8(randomWord % GRID_SIZE);
        games[currentGameIndex].treasurePosition = initialTreasurePosition;

        emit GameStarted(currentGameIndex, games[currentGameIndex].tvl, initialTreasurePosition);
    }

    /**
     * @dev Validate the player's new position based on the input direction.
     * @param position current position of user in the game.
     * @param move The direction of the move.
     * @return nextPosition The validated new position.
     */
    function _newPosition(uint8 position, Directions move, bool isTest) internal view returns (uint8 nextPosition) {
        if (isTest) {
            return latestPlayerPosition;
        } else {
            uint8 y = position / 10; // y axis of the board
            uint8 x = position % 10; // x axis of the board

            if (move == Directions.Left) {
                nextPosition = (x == 0) ? 100 : position - 1;
            } else if (move == Directions.Top) {
                nextPosition = (y == 0) ? 100 : position - 10;
            } else if (move == Directions.Right) {
                nextPosition = (x == 9) ? 100 : position + 1;
            } else if (move == Directions.Bottom) {
                nextPosition = (y == 9) ? 100 : position + 10;
            }

            // 100 is a number outside bounds of the board, hence used to check invalid move
            if (nextPosition == 100) {
                revert InvalidMove(move, position);
            }
        }
    }

    /**
     * @dev Generate a random position on the grid.
     * @return uint8 The generated random position.
     */
    function _generateInitialRandomPosition() internal view returns (uint8) {
        return uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.number))) % GRID_SIZE);
    }
}
