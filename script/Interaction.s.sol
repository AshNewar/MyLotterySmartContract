//SPDX-License-Identifier:MIT

pragma solidity 0.8.18;
import {Script, console} from "forge-std/Script.sol";
import {Config} from "./Config.s.sol";
import {VRFCoordinatorV2Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract createSubscriptionMock is Script {
    function createSubscriptionConfig() public returns (uint64) {
        Config config = new Config();
        (, , address vrfCoordinator, , , , , uint keys) = config
            .activeNetworkConfig();
        return createSubscription(vrfCoordinator, keys);
    }

    function createSubscription(
        address vrfCoordinate,
        uint keys
    ) public returns (uint64) {
        console.log("Starting ChainLink on id: ", block.chainid);
        vm.startBroadcast(keys);
        uint64 subscriptionId = VRFCoordinatorV2Mock(vrfCoordinate)
            .createSubscription();
        vm.stopBroadcast();
        console.log("SubscriptionId: ", subscriptionId);
        return subscriptionId;
    }

    function run() external returns (uint64) {
        return createSubscriptionConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant fundAmount = 3 ether;

    function fundSubscriptionConfig() public {
        Config config = new Config();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subscriptionid,
            ,
            address link,
            uint keys
        ) = config.activeNetworkConfig();
        fundSubsciption(vrfCoordinator, subscriptionid, link, keys);
    }

    function fundSubsciption(
        address vrfCoordinator,
        uint64 subId,
        address link,
        uint keys
    ) public {
        console.log("Funding ChainLink on id: ", block.chainid);
        console.log("SubscriptionId: ", subId);
        console.log("Link: ", link);
        if (block.chainid == 31337) {
            vm.startBroadcast(keys);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subId,
                fundAmount
            );
            vm.stopBroadcast();
        } else {
            console.log(LinkToken(link).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(link).balanceOf(address(this)));
            vm.startBroadcast(keys);
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                fundAmount,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(
        address contractAddress,
        address vrfCoordinator,
        uint64 subId,
        uint deployerkeys
    ) public {
        console.log("Adding Consumer");
        // console.log("Contract Address: ", contractAddress);
        // console.log("VrfCoordinator: ", vrfCoordinator);
        // console.log("SubscriptionId: ", subId);
        console.log("DeployerKeys", deployerkeys);
        vm.startBroadcast(deployerkeys);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(
            subId,
            contractAddress
        );
        vm.stopBroadcast();
    }

    function addConsumerConfig(address contractAddress) public {
        Config config = new Config();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subscriptionid,
            ,
            ,
            uint keys
        ) = config.activeNetworkConfig();
        addConsumer(contractAddress, vrfCoordinator, subscriptionid, keys);
    }

    function run() external {
        address contractAddress = DevOpsTools.get_most_recent_deployment(
            "Lottery",
            block.chainid
        );
        addConsumerConfig(contractAddress);
    }
}
