// SPDX-License-Identifier: MIT
// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions
pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {console} from "forge-std/console.sol";

/**
 * @title Lottery
 * @author Ashish Newar
 * @notice This contract is used for lottery
 */
contract Lottery is VRFConsumerBaseV2 {
    error Lottery_NotEnoughEther();
    error Lottery_TransferFailed();
    error Lottery_UnActive();
    error Lottery_UpkeepError(
        uint balance,
        uint playersLength,
        LotteryState state
    );

    enum LotteryState {
        OPEN,
        CALCULATING_WINNER
    }

    uint16 private constant requestConfirmations = 3;
    uint32 private constant numWords = 1;

    uint private immutable entryPrice;
    uint private immutable intervalTime;
    uint private lastTimeStamp;
    uint64 private immutable s_subscriptionId;
    uint32 private immutable callbackGasLimit;
    VRFCoordinatorV2Interface private immutable vrfCOORDINATOR;
    bytes32 private immutable keyHash;
    address payable[] private players;
    address private recentWinner;
    event EnteredPlayers(address indexed player);
    event Winners(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    LotteryState private state;

    constructor(
        uint price,
        uint interval,
        address vrfCoordinator,
        bytes32 keyhash,
        uint64 subscriptionid,
        uint32 gasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        entryPrice = price;
        intervalTime = interval;
        lastTimeStamp = block.timestamp;
        vrfCOORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        keyHash = keyhash;
        s_subscriptionId = subscriptionid;
        callbackGasLimit = gasLimit;
        state = LotteryState.OPEN;
    }

    function getEntranceFee() public view returns (uint) {
        return entryPrice;
    }

    function Enter() external payable {
        if (msg.value < entryPrice) {
            revert Lottery_NotEnoughEther();
        }
        if (state != LotteryState.OPEN) {
            revert Lottery_UnActive();
        }

        players.push(payable(msg.sender));
        emit EnteredPlayers(msg.sender);
    }

    //triggers the pickWinner function

    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool time = (block.timestamp - lastTimeStamp) >= intervalTime;
        bool hasbalance = address(this).balance > 0;
        bool hasPlayers = players.length > 0;
        bool isOpen = state == LotteryState.OPEN;
        console.log(time, hasbalance, hasPlayers, isOpen);
        upkeepNeeded = time && hasbalance && hasPlayers && isOpen;
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Lottery_UpkeepError(
                address(this).balance,
                players.length,
                state
            );
        }
        state = LotteryState.CALCULATING_WINNER;
        //Picking Random Number
        uint256 requestId = vrfCOORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
        emit RequestedRaffleWinner(requestId);
    }

    //CEI Rules ->Check Effects Interactions
    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        //Check Errors

        //Effects
        uint winnerIndex = randomWords[0] % players.length;
        address payable winner = players[winnerIndex];
        recentWinner = winner;
        players = new address payable[](0);
        lastTimeStamp = block.timestamp;
        state = LotteryState.OPEN;
        emit Winners(winner);
        // console.log("Before BAlance", address(winner).balance);

        //Interactions
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Lottery_TransferFailed();
        }
    }

    function getState() external view returns (LotteryState) {
        return state;
    }

    function getPlayer(uint index) external view returns (address) {
        return players[index];
    }

    function getRecentWinner() external view returns (address) {
        return recentWinner;
    }

    function getArrayLength() external view returns (uint) {
        return players.length;
    }

    function getLastTimeStamp() external view returns (uint) {
        return lastTimeStamp;
    }
}
