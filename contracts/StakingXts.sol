// SPDX-License-Identifier: NONE
pragma solidity ^0.8.0;
pragma abicoder v2;

import "./XtsToken.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract StakingXts {

    using SafeMath for uint256;

    event Staked(address indexed user, uint amount);
    event UnStaked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    address public owner;
    address[] public stakers;
    mapping (address => uint) public stakes;
    uint public totalStakes;
    mapping (address => uint) public balances;

    modifier onlyOwner() {
    require(msg.sender == owner, "not owner");
    _;
    }


    struct RewardPeriod {
        uint id;
        uint reward;
        uint from;
        uint to;
        uint lastUpdated; // when the totalStakedWeight was last updated (after last stake was ended)
        uint totalStaked; // T: sum of all active stake deposits
        uint rewardPerTokenStaked; // S: SUM(reward/T) - sum of all rewards distributed divided all active stakes
        uint totalRewardsPaid; 
    }

    struct RewardsStats {
        // user stats
        uint claimableRewards;
        uint rewardsPaid;
        // general stats
        uint rewardRate;
        uint totalRewardsPaid;
    }

    struct UserInfo {
        uint userRewardPerTokenStaked;
        uint pendingRewards;
        uint rewardsPaid;
    }

    XtsToken internal rewardToken;
    RewardPeriod[] public rewardPeriods;
    uint public rewardPeriodsCount = 0;


    mapping(address => UserInfo) public userInfos;

    uint constant rewardPrecision = 1e9;
 
    constructor(address _rewardTokenAddress, address _lpTokenAddress) {}

    function startStake(uint amount) virtual public {
        require(amount > 0, "Can't be zero");
        require(balances[msg.sender] >= amount, "Not enough tokens to stake");

        // move tokens from lp token balance to the staked balance
        balances[msg.sender] = balances[msg.sender] - amount;
        stakes[msg.sender] = stakes[msg.sender] + amount; 
       
        totalStakes = totalStakes + amount;

        emit Staked(msg.sender, amount);
    }


    function endStake(uint amount) virtual public {
        require(stakes[msg.sender] >= amount, "Not enough tokens staked");

        // return lp tokens to lp token balance
        balances[msg.sender] = balances[msg.sender] + amount;
        stakes[msg.sender] = stakes[msg.sender] - amount; 

        totalStakes = totalStakes - amount;

        emit UnStaked(msg.sender, amount);
    }


    function getStakedBalance() public view returns (uint) {
        return stakes[msg.sender];
    }


    function newRewardPeriod(uint reward, uint from, uint to) public onlyOwner {
        require(reward > 0, "Invalid reward period amount");
        require(to > from && to > block.timestamp, "Invalid reward period interval");
        require(rewardPeriods.length == 0 || from > rewardPeriods[rewardPeriods.length-1].to, "Invalid period start time");

        rewardPeriods.push(RewardPeriod(rewardPeriods.length+1, reward, from, to, block.timestamp, 0, 0, 0));
        rewardPeriodsCount = rewardPeriods.length;
        depositReward(reward);
    }


    function getRewardPeriodsCount() public view returns(uint) {
        return rewardPeriodsCount;
    }

    function claimableReward() view public returns (uint) {
        uint periodId = getCurrentRewardPeriodId();
        if (periodId == 0) return 0;

        RewardPeriod memory period = rewardPeriods[periodId-1];
        uint newRewardDistribution = calculateRewardDistribution(period);
        uint reward = calculateReward(newRewardDistribution);

        UserInfo memory userInfo = userInfos[msg.sender];
        uint pending = userInfo.pendingRewards;

        return pending += reward;
    }

    function claim() internal {
        UserInfo storage userInfo = userInfos[msg.sender];
        uint rewards = userInfo.pendingRewards;
        if (rewards != 0) {
            userInfo.pendingRewards = 0;

            uint periodId = getCurrentRewardPeriodId();
            RewardPeriod storage period = rewardPeriods[periodId-1];
            period.totalRewardsPaid = period.totalRewardsPaid + rewards;

            payReward(msg.sender, rewards);
        }
    }

    function depositReward(uint amount) internal onlyOwner {
        rewardToken.transferFrom(msg.sender, address(this), amount);
    }

    function payReward(address account, uint reward) internal {
        UserInfo storage userInfo = userInfos[msg.sender];
        userInfo.rewardsPaid = userInfo.rewardsPaid + reward;
        rewardToken.transfer(account, reward);

        emit RewardPaid(account, reward);
    }

    function calculateRewardDistribution(RewardPeriod memory period) internal view returns (uint) {

        // calculate total reward to be distributed since period.lastUpdated
        uint rate = rewardRate(period);
        uint deltaTime = block.timestamp - period.lastUpdated;
        uint reward = deltaTime.mul(rate);

        uint newRewardPerTokenStaked = period.rewardPerTokenStaked;  // 0
        if (period.totalStaked != 0) {
            // S = S + r / T
            newRewardPerTokenStaked = period.rewardPerTokenStaked.add( 
                reward.mul(rewardPrecision).div(period.totalStaked)
            );
        }

        return newRewardPerTokenStaked;
    }


    function calculateReward(uint rewardDistribution) internal view returns (uint) {
        if (rewardDistribution == 0) return 0;

        uint staked = stakes[msg.sender];
        UserInfo memory userInfo = userInfos[msg.sender];
        uint reward = staked.mul(
            rewardDistribution.sub(userInfo.userRewardPerTokenStaked)
        ).div(rewardPrecision);

        return reward;
    }

    function getCurrentRewardPeriodId() public view returns (uint) {
        if (rewardPeriodsCount == 0) return 0;
        for (uint i=rewardPeriods.length; i>0; i--) {
            RewardPeriod memory period = rewardPeriods[i-1];
            if (period.from <= block.timestamp && period.to >= block.timestamp) {
                return period.id;
            }
        }
        return 0;
    }


    function getRewardsStats() public view returns (RewardsStats memory) {
        UserInfo memory userInfo = userInfos[msg.sender];

        RewardsStats memory stats = RewardsStats(0, 0, 0, 0);
        // user stats
        stats.claimableRewards = claimableReward();
        stats.rewardsPaid = userInfo.rewardsPaid;

        // reward period stats
        uint periodId = getCurrentRewardPeriodId();
        if (periodId > 0) {
            RewardPeriod memory period = rewardPeriods[periodId-1];
            stats.rewardRate = rewardRate(period);
            stats.totalRewardsPaid = period.totalRewardsPaid;
        }

        return stats;
    }


    function rewardRate(RewardPeriod memory period) internal pure returns (uint) {
        uint duration = period.to.sub(period.from);
        return period.reward.div(duration);
    }
}