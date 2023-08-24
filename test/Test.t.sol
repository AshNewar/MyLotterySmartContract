//SPDX-License-Identifier:MIT

pragma solidity 0.8.18;
import {Test, console} from "forge-std/Test.sol";
import {Deploy} from "../script/DeployScript.s.sol";
import {Lottery} from "../src/Lottery.sol";
import {Config} from "../script/Config.s.sol";
import {VRFCoordinatorV2Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {Vm} from "forge-std/Vm.sol";

contract TestContract is Test {
    Deploy deploy;
    Lottery lottery;
    Config config;
    uint entryFee = 0.01 ether;
    address public PLAYER = makeAddr("player");
    uint256 public balance = 10 ether;
    uint price;
    uint interval;
    address vrfCoordinator;
    bytes32 keyhash;
    uint64 subscriptionid;
    uint32 gasLimit;
    address link;
    // uint keys;
    event EnteredPlayers(address indexed player);

    function setUp() external {
        deploy = new Deploy();
        (lottery, config) = deploy.run();
        (
            price,
            interval,
            vrfCoordinator,
            keyhash,
            subscriptionid,
            gasLimit,
            link,
            // keys

        ) = config.activeNetworkConfig();
        vm.deal(PLAYER, balance);

        // setup code here
    }

    function testState() external view {
        assert(lottery.getState() == Lottery.LotteryState.OPEN);
    }

    function testEnoughFund() external {
        vm.prank(PLAYER);
        vm.expectRevert(Lottery.Lottery_NotEnoughEther.selector);
        lottery.Enter{value: 0.001 ether}(); //Not Enough Fund
    }

    function testPlayerArray() external {
        vm.prank(PLAYER);
        lottery.Enter{value: entryFee}();
        address playerEntered = lottery.getPlayer(0);
        console.log(playerEntered);
        assert(playerEntered == PLAYER);
    }

    function testEvent() external {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(lottery));
        emit EnteredPlayers(PLAYER);
        lottery.Enter{value: entryFee}();
    }

    function testWhileCalculating() external {
        vm.prank(PLAYER);
        lottery.Enter{value: entryFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        lottery.performUpkeep("");
        vm.expectRevert(Lottery.Lottery_UnActive.selector);
        vm.prank(PLAYER);
        lottery.Enter{value: entryFee}();
    }

    function testUpKeepWhenBalanceZero() external {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeep, ) = lottery.checkUpkeep("");
        assert(upkeep == false);
    }

    function testUpKeepWhenNotOpen() external {
        vm.prank(PLAYER);
        lottery.Enter{value: entryFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        lottery.performUpkeep("");

        //Checking
        (bool upkeep, ) = lottery.checkUpkeep("");
        assert(upkeep == false);
    }

    function testUpKeepWhenTime() external view {
        (bool upkeep, ) = lottery.checkUpkeep("");
        assert(!upkeep);
    }

    function testUpKeepAllTrue() external {
        vm.prank(PLAYER);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        lottery.Enter{value: entryFee}();
        (bool upkeep, ) = lottery.checkUpkeep("");
        assert(upkeep);
    }

    function testPerformUpkeep() external {
        vm.prank(PLAYER);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        lottery.Enter{value: entryFee}();

        lottery.performUpkeep("");
    }

    function testPerformUpkeepFalse() external {
        //I m Telling that it will revert due to the following parameters given (0,0,0);
        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery.Lottery_UpkeepError.selector,
                0,
                0,
                0
            )
        );
        lottery.performUpkeep("");
    }

    modifier addPlayer() {
        vm.prank(PLAYER);
        lottery.Enter{value: entryFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    //Fuzzing The test

    function testFulFilRandom(uint256 randomInt) public addPlayer skipFork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomInt,
            address(lottery)
        );
    }

    function testAll() external skipFork {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        uint numberOfPlayer = 5;
        for (uint i = 1; i <= numberOfPlayer; i++) {
            address player = address(uint160(i));
            hoax(player, balance);
            lottery.Enter{value: entryFee}();
        }
        uint totalprice = entryFee * numberOfPlayer;

        vm.recordLogs();
        lottery.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        uint previousTimeStamp = lottery.getLastTimeStamp();

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(lottery)
        );
        // console.log(lottery.getRecentWinner().balance);
        // console.log(totalprice + balance - entryFee);
        // console.log(totalprice);
        // console.log(balance);
        // console.log(entryFee);

        assert(uint256(lottery.getState()) == 0);
        assert(lottery.getRecentWinner() != address(0));
        assert(lottery.getArrayLength() == 0);
        assert(previousTimeStamp < lottery.getLastTimeStamp());
        assert(
            lottery.getRecentWinner().balance == totalprice + balance - entryFee
        );
    }
}
