// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../src/StakingPool.sol";

contract StakingPool is Test {

    struct Stake {
        uint128 amount;
        uint128 lastUpdatedCumulatedAverage;
        uint128 cumulatedKKToken;
    }

    struct TotalStakeAverage {
        uint128 totalStake;
        uint128 lastUpdatedBlockNumber;
        uint128 lastUpdatedCumulatedAverage;
    }

    KKStakingPool staking_ca;
    KKToken kk_ca;
    address alice;
    uint256 initialBlock;
    address admin;

    function setUp() public {

        admin = makeAddr("admin");

         vm.startPrank(admin);

        kk_ca = new KKToken();
        staking_ca = new KKStakingPool(address(kk_ca));

        kk_ca.transfer(address(staking_ca), 1000000000 * 10**18 );
        alice = makeAddr("alice");
        KKToken(kk_ca).transfer(address(staking_ca) , 100 ether);

    }

    function test_stake() public {

        vm.deal(alice, 100 ether);      
       
        vm.startPrank(alice);
        staking_ca.stake{value:10 ether}();
        vm.stopPrank();

        assertEq(alice.balance , 90 ether);
        assertEq(address(staking_ca).balance, 10 ether);
        console.log(alice.balance , "=======================>0");
        console.log(address(staking_ca).balance, "=======================>1");
    }

    function test_unstake() public { 

        initialBlock = block.number;
        test_stake();
        uint256 newBlockNumber = initialBlock + 100;
        vm.roll(newBlockNumber);
        vm.startPrank(alice);
        staking_ca.unstake(10 ether);
        vm.stopPrank();
        assertEq(address(staking_ca).balance, 0 ether);
        console.log(address(staking_ca).balance,"=======================>2");
    }

    function test_claim() public {

        console.log(kk_ca.balanceOf(address(staking_ca)),"kk_ca=======================>3");

        vm.deal(alice, 200 ether);
        initialBlock = block.number;
         // 记录初始区块高度
        vm.startPrank(alice);
        staking_ca.stake{value:10 ether}();
        vm.stopPrank();
        uint256 newBlockNumber = initialBlock + 1000;
        vm.roll(newBlockNumber);
        vm.startPrank(alice);
        staking_ca.claim();
        vm.stopPrank();
        console.log(kk_ca.balanceOf(alice),"=======================>3");

    }
}
