pragma solidity ^0.8.25;

import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol"; // 导入 Forge 的 console.sol，用于调试打印信息
import {Test, console} from "forge-std/Test.sol";
contract KKStakingPool {
    struct Stake {
        uint128 amount; // 用户质押的 ETH 数量
        uint128 cumulatedKKToken; // 用户累积的 KK Token 数量
        uint128 lastUpdatedCumulatedAverage; // 上次更新的累积平均值
    }

    struct TotalStakeAverage {
        uint128 totalStake; // 总质押数量
        uint128 lastUpdatedBlockNumber; // 上次更新的区块号
        uint128 lastUpdatedCumulatedAverage; // 上次更新的累积平均值
    }

    address public immutable kk_ca; // KK Token 合约地址

    TotalStakeAverage public totalAverage; // 总质押的平均值信息
    mapping(address => Stake) public records; // 用户的质押记录

    event Staked(address indexed staker, uint128 amount); // 质押事件
    event Unstaked(address indexed staker, uint128 amount); // 提取质押事件
    event Claimed(address indexed staker, uint128 amount); // 领取奖励事件

    constructor(address _kk_ca) {
        kk_ca = _kk_ca; // 初始化 KK Token 合约地址
    }

    receive() external payable {}

    // 用户质押 ETH 到池子中
    function stake() external payable {
        require(msg.value > 0, "Amount must be greater than 0"); // 质押数量必须大于 0
        uint128 currentBlock = uint128(block.number);  // 区块高度
        Stake storage record = records[msg.sender]; // 获取用户的质押记录
        // 
        totalAverage.totalStake += uint128(msg.value); // 总质押数量
        //  上次更新的累积平均值 ----- = 每个区块的奖励 * （ 当前区块高度 -  上一次更新的区块高度）/ 质押总数量
        totalAverage.lastUpdatedCumulatedAverage += 1e6 * 10 ether * (currentBlock - totalAverage.lastUpdatedBlockNumber) / totalAverage.totalStake; // 乘以 1e6 避免小数
        totalAverage.lastUpdatedBlockNumber = currentBlock;  // 更新区块高度

        // 用户获取的 kktoken    = 用户的质押数量 * （全局的累积平局值 - 用户上一次记录的累积平均值）/ 1e16
        record.cumulatedKKToken += record.amount * (totalAverage.lastUpdatedCumulatedAverage - record.lastUpdatedCumulatedAverage) / 1e6;
        record.lastUpdatedCumulatedAverage = totalAverage.lastUpdatedCumulatedAverage;
        record.amount += uint128(msg.value);

        emit Staked(msg.sender, uint128(msg.value)); // 触发质押事件
    }

    // 用户提取质押的 ETH
    function unstake(uint128 amount) external {
        require(amount > 0, "Amount must be greater than 0"); // 提取数量必须大于 0
        Stake storage record = records[msg.sender]; // 获取用户的质押记录
        require(record.amount >= amount, "Insufficient staked amount"); // 用户的质押数量必须大于等于提取数量
        uint128 currentBlock = uint128(block.number);
        require(currentBlock > totalAverage.lastUpdatedBlockNumber, "block does not change"); // 区块必须发生变化 当前区块高度 -

        // 更新总质押数量和累积平均值
        totalAverage.lastUpdatedCumulatedAverage += 1e6 * 10 ether * (currentBlock - totalAverage.lastUpdatedBlockNumber) / totalAverage.totalStake; // 乘以 1e6 避免小数
        totalAverage.totalStake -= amount;
        totalAverage.lastUpdatedBlockNumber = currentBlock;

        // 更新用户的质押记录
        record.cumulatedKKToken +=  record.amount * (totalAverage.lastUpdatedCumulatedAverage - record.lastUpdatedCumulatedAverage) / 1e6;
        record.lastUpdatedCumulatedAverage = totalAverage.lastUpdatedCumulatedAverage; 
        record.amount -= amount;

        // 向用户转账提取的 ETH
        (bool success,) = payable(msg.sender).call{value: amount}("");
        require(success, "Failed to send Ether");

        emit Unstaked(msg.sender, amount); // 触发提取质押事件
    }

    // 用户领取奖励 KK Token
    function claim() external {
        Stake storage record = records[msg.sender]; // 获取用户的质押记录
        require(record.amount > 0, "Nothing to claim"); // 用户必须有质押数量
        uint128 currentBlock = uint128(block.number);
        require(currentBlock > totalAverage.lastUpdatedBlockNumber, "block does not change"); // 区块必须发生变化

        // 更新累总的积平均值和区块高度
        totalAverage.lastUpdatedCumulatedAverage +=
            1e6 * 10 ether * (currentBlock - totalAverage.lastUpdatedBlockNumber) / totalAverage.totalStake; // 乘以 1e6 避免小数
        totalAverage.lastUpdatedBlockNumber = currentBlock;

        // 更新用户的质押记录 
        record.cumulatedKKToken += record.amount * (totalAverage.lastUpdatedCumulatedAverage - record.lastUpdatedCumulatedAverage) / 1e6;
        record.lastUpdatedCumulatedAverage = totalAverage.lastUpdatedCumulatedAverage;

        uint128 canClaim = record.cumulatedKKToken;
        console.log(canClaim,"canClaim======================>");
        record.cumulatedKKToken = 0;

        IERC20(kk_ca).transfer(msg.sender, canClaim);
        emit Claimed(msg.sender, canClaim);
    }

    function balanceOf(address account) external view returns (uint256) {
        return records[account].amount;
    }
    // 查询获得的奖励 ecord.cumulatedKKToken 是用户stake 或者unstake 的时候的奖励，要加上stake 或者unstake  到现在的奖励
    function earned(address account) external view returns (uint256) {
        Stake storage record = records[account];
        uint128 cumulatedKKToken = record.cumulatedKKToken
            + record.amount * (totalAverage.lastUpdatedCumulatedAverage - record.lastUpdatedCumulatedAverage) / 1 ether;

        return cumulatedKKToken;
    }
  
}
    contract KKToken is ERC20 {
        constructor() ERC20("KK Token", "KKT") {
            _mint(msg.sender, 10000000000 ether);
        }
    
        function mint(address to, uint256 amount) public {
            _mint(to, amount);
        }
    }

