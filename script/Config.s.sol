//SPDX-licensce-Identifier:MIT

pragma solidity ^0.8.18;
import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

// import {console}
contract Config is Script {
    struct Network {
        uint price;
        uint interval;
        address vrfCoordinator;
        bytes32 keyhash;
        uint64 subscriptionid;
        uint32 gasLimit;
        address link;
        uint256 keys;
    }
    Network public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepolia();
        } else {
            activeNetworkConfig = getOrCreateAnvil();
        }
        //Rinkeby
    }

    function getSepolia() public view returns (Network memory) {
        return
            Network({
                price: 0.01 ether,
                interval: 1 minutes,
                vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                keyhash: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionid: 4743,
                gasLimit: 500000,
                link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                keys: vm.envUint("PRIVATE_KEYS")
            });
    }

    function getOrCreateAnvil() public returns (Network memory) {
        uint256 localKeys = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }
        uint96 basePrice = 0.1 ether;
        uint96 gasPriceLink = 1e9; //1gwei
        console.log("Local keys", localKeys);

        vm.startBroadcast(localKeys);
        VRFCoordinatorV2Mock vrfCoordinator = new VRFCoordinatorV2Mock(
            basePrice,
            gasPriceLink
        );
        LinkToken link = new LinkToken();
        vm.stopBroadcast();
        return
            Network({
                price: 0.01 ether,
                interval: 1 minutes,
                vrfCoordinator: address(vrfCoordinator),
                keyhash: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscriptionid: 0,
                gasLimit: 500000,
                link: address(link),
                keys: localKeys
            });
    }
}
