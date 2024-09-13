// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface INFTCertificate is IERC721 {
    function mint(address to) external returns (uint256);
}

contract StakingContract is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public tokenA;
    INFTCertificate public nftCertificate;

    uint256 public constant LOCK_PERIOD = 5 minutes;
    uint256 public constant MIN_DEPOSIT_FOR_NFT = 1_000_000 * 1e18; // 1M tokens
    uint256 public baseAPR = 800; // 8.00%
    uint256 public constant NFT_APR_BOOST = 200; // 2.00%

    struct Stake {
        uint256 amount;
        uint256 timestamp;
        uint256 lockEndTime;
        uint256 lastClaimTime;
        uint256 nftCount;
        uint256 pendingRewards;
        uint256 apr;
    }

    mapping(address => Stake) public stakes;
    mapping(address => uint256[]) public userTransactions;

    address[] public stakers;
    mapping(address => bool) public isStaker;

    uint256 public totalStaked;
    uint256 public totalRewardsPaid;

    bool public emergencyStop;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event NFTMinted(address indexed user, uint256 tokenId);
    event NFTDeposited(address indexed user, uint256 tokenId);
    event NFTWithdrawn(address indexed user, uint256 tokenId);
    event BaseAPRUpdated(uint256 oldAPR, uint256 newAPR);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event NFTStaked(address indexed user, uint256 tokenId);

    constructor(address _tokenA, address _nftCertificate) Ownable(msg.sender) {
        tokenA = IERC20(_tokenA);
        nftCertificate = INFTCertificate(_nftCertificate);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(!emergencyStop, "Emergency stop is activated");
        
        Stake storage userStake = stakes[msg.sender];
        
        if (userStake.amount > 0) {
            uint256 reward = calculateReward(msg.sender);
            userStake.lastClaimTime = block.timestamp;
            userStake.pendingRewards += reward;
        } else {
            userStake.lastClaimTime = block.timestamp;
            userStake.apr = baseAPR;
        }

        tokenA.safeTransferFrom(msg.sender, address(this), amount);

        userStake.amount += amount;
        userStake.timestamp = block.timestamp;
        userStake.lockEndTime = block.timestamp + LOCK_PERIOD;

        uint256 newNFTCount = userStake.amount / MIN_DEPOSIT_FOR_NFT;
        if (newNFTCount > userStake.nftCount) {
            uint256 nftsToMint = newNFTCount - userStake.nftCount;
            for (uint256 i = 0; i < nftsToMint; i++) {
                uint256 tokenId = nftCertificate.mint(msg.sender);
                emit NFTMinted(msg.sender, tokenId);
            }
        }

        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(!emergencyStop, "Emergency stop is activated");
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount >= amount, "Insufficient balance");
        require(block.timestamp >= userStake.lockEndTime, "Tokens are still locked");

        uint256 reward = calculateReward(msg.sender);
        
        
        userStake.pendingRewards = userStake.pendingRewards + reward;
        userStake.lastClaimTime = block.timestamp;

        require(tokenA.balanceOf(address(this)) >= amount, "Insufficient contract balance");

       
        unchecked {
            userStake.amount -= amount;
            totalStaked -= amount;
        }
        
        tokenA.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function claimReward() external {
        require(!emergencyStop, "Emergency stop is activated");
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No stake found");

        uint256 reward = calculateReward(msg.sender) + userStake.pendingRewards;
        require(reward > 0, "No reward to claim");

        userStake.lastClaimTime = block.timestamp;
        userStake.pendingRewards = 0;

        tokenA.safeTransfer(msg.sender, reward);

        totalRewardsPaid += reward;
        emit RewardClaimed(msg.sender, reward);
    }

    function calculateReward(address user) internal view returns (uint256) {
        Stake storage userStake = stakes[user];
        if (userStake.amount == 0) return 0;
        
        uint256 timeElapsed = block.timestamp - userStake.lastClaimTime;
        uint256 effectiveAPR = userStake.apr + (userStake.nftCount * NFT_APR_BOOST);
        
        
        uint256 reward = (userStake.amount * effectiveAPR * timeElapsed) / (365 days * 10000);
        
        return reward;
    }

    function depositNFT(uint256 tokenId) external {
        require(!emergencyStop, "Emergency stop is activated");
        require(nftCertificate.ownerOf(tokenId) == msg.sender, "You don't own this NFT");
        nftCertificate.transferFrom(msg.sender, address(this), tokenId);

        Stake storage userStake = stakes[msg.sender];
        uint256 reward = calculateReward(msg.sender);
        userStake.pendingRewards += reward;
        userStake.lastClaimTime = block.timestamp;
        userStake.nftCount++;
        userStake.apr += NFT_APR_BOOST;

        emit NFTDeposited(msg.sender, tokenId);
    }

    function withdrawNFT(uint256 tokenId) external {
        require(!emergencyStop, "Emergency stop is activated");
        require(nftCertificate.ownerOf(tokenId) == address(this), "Contract doesn't own this NFT");
        
        Stake storage userStake = stakes[msg.sender];
        require(userStake.nftCount > 0, "No NFTs to withdraw");

        uint256 reward = calculateReward(msg.sender);
        userStake.pendingRewards += reward;
        userStake.lastClaimTime = block.timestamp;
        userStake.nftCount--;
        userStake.apr -= NFT_APR_BOOST;

        nftCertificate.transferFrom(address(this), msg.sender, tokenId);

        emit NFTWithdrawn(msg.sender, tokenId);
    }

    function mintNFT() external {
        require(stakes[msg.sender].amount >= MIN_DEPOSIT_FOR_NFT, "Not enough staked tokens to mint NFT");
        uint256 tokenId = nftCertificate.mint(msg.sender);
        emit NFTMinted(msg.sender, tokenId);
    }

    function stakeNFT(uint256 tokenId) external {
        require(!emergencyStop, "Emergency stop is activated");
        require(nftCertificate.ownerOf(tokenId) == msg.sender, "You don't own this NFT");
        nftCertificate.transferFrom(msg.sender, address(this), tokenId);

        Stake storage userStake = stakes[msg.sender];
        uint256 reward = calculateReward(msg.sender);
        userStake.pendingRewards += reward;
        userStake.lastClaimTime = block.timestamp;
        userStake.nftCount++;
        userStake.apr += NFT_APR_BOOST;

        emit NFTStaked(msg.sender, tokenId);
    }

    function setBaseAPR(uint256 newAPR) external onlyOwner {
        uint256 oldAPR = baseAPR;
        baseAPR = newAPR;
        emit BaseAPRUpdated(oldAPR, newAPR);
    }

    function getUserTransactions(address user, uint256 offset, uint256 limit) 
        public 
        view 
        returns (uint256[] memory) 
    {
        uint256[] storage transactions = userTransactions[user];
        uint256 end = offset + limit > transactions.length ? transactions.length : offset + limit;
        uint256 size = end - offset;
        
        uint256[] memory result = new uint256[](size);
        for (uint256 i = 0; i < size; i++) {
            result[i] = transactions[offset + i];
        }
        return result;
    }

    function getAllTransactions(uint256 offset, uint256 limit) 
        external 
        view 
        onlyOwner 
        returns (address[] memory, uint256[][] memory) 
    {
        uint256 end = offset + limit > stakers.length ? stakers.length : offset + limit;
        uint256 size = end - offset;
        
        address[] memory users = new address[](size);
        uint256[][] memory transactions = new uint256[][](size);
        
        for (uint256 i = 0; i < size; i++) {
            address user = stakers[offset + i];
            users[i] = user;
            transactions[i] = getUserTransactions(user, 0, userTransactions[user].length);
        }
        
        return (users, transactions);
    }

    function searchTransactionsByAddress(address user, uint256 offset, uint256 limit) 
        external 
        view 
        onlyOwner 
        returns (uint256[] memory) 
    {
        return getUserTransactions(user, offset, limit);
    }

    function getStakeInfo(address user) external view returns (Stake memory) {
        return stakes[user];
    }

    function getTotalStakedAndRewards() external view returns (uint256, uint256) {
        return (totalStaked, totalRewardsPaid);
    }

    function setEmergencyStop(bool _stop) external onlyOwner {
        emergencyStop = _stop;
    }

    function emergencyWithdraw() external {
        require(emergencyStop, "Emergency stop is not activated");
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No stake to withdraw");

        uint256 amount = userStake.amount;
        userStake.amount = 0;
        userStake.nftCount = 0;
        userStake.pendingRewards = 0;
        
        totalStaked -= amount;
        tokenA.safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(msg.sender, amount);
    }

    function getWithdrawableAmount(address user) public view returns (uint256 withdrawableAmount, uint256 pendingReward) {
        Stake storage userStake = stakes[user];
        withdrawableAmount = userStake.amount;
        pendingReward = userStake.pendingRewards + calculateReward(user);
        return (withdrawableAmount, pendingReward);
    }

    function getStakedNFTs(address user) public view returns (uint256[] memory) {
        Stake storage userStake = stakes[user];
        uint256[] memory stakedNFTs = new uint256[](userStake.nftCount);
        uint256 count = 0;
        for (uint256 i = 0; i < userStake.nftCount; i++) {
            uint256 tokenId = i; 
            if (nftCertificate.ownerOf(tokenId) == address(this)) {
                stakedNFTs[count] = tokenId;
                count++;
            }
        }
        return stakedNFTs;
    }
}