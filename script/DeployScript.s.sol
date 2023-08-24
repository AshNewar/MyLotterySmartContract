//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {Lottery} from "../src/Lottery.sol";
import {Config} from "./Config.s.sol";
import {createSubscriptionMock, FundSubscription, AddConsumer} from "./Interaction.s.sol";

contract Deploy is Script {
    function run() external returns (Lottery, Config) {
        Config config = new Config();
        (
            uint price,
            uint interval,
            address vrfCoordinator,
            bytes32 keyhash,
            uint64 subscriptionid,
            uint32 gasLimit,
            address link,
            uint keys
        ) = config.activeNetworkConfig();

        if (subscriptionid == 0) {
            createSubscriptionMock create = new createSubscriptionMock();
            subscriptionid = create.createSubscription(vrfCoordinator, keys);
        }

        //Fund The Subscription -->
        FundSubscription fund = new FundSubscription();
        fund.fundSubsciption(vrfCoordinator, subscriptionid, link, keys);

        vm.startBroadcast(keys);
        Lottery lottery = new Lottery(
            price,
            interval,
            vrfCoordinator,
            keyhash,
            subscriptionid,
            gasLimit
        );
        vm.stopBroadcast();

        AddConsumer consumer = new AddConsumer();
        consumer.addConsumer(
            address(lottery),
            vrfCoordinator,
            subscriptionid,
            keys
        );
        return (lottery, config);
    }
}
