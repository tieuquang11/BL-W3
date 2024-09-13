const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("StakingContract", function () {
    let stakingContract;
    let tokenA;
    let nftCertificate;
    let owner;
    let user1;
    let user2;

    beforeEach(async function () {
        [owner, user1, user2] = await ethers.getSigners();

        const TokenA = await ethers.getContractFactory("TokenA");
        tokenA = await TokenA.deploy(ethers.parseEther("1000000"));
        await tokenA.waitForDeployment();

        const NFTCertificate = await ethers.getContractFactory("NFTCertificate");
        nftCertificate = await NFTCertificate.deploy();
        await nftCertificate.waitForDeployment();

        const StakingContract = await ethers.getContractFactory("StakingContract");
        stakingContract = await StakingContract.deploy(await tokenA.getAddress(), await nftCertificate.getAddress());
        await stakingContract.waitForDeployment();

        // Grant minter role to StakingContract
        await nftCertificate.transferOwnership(await stakingContract.getAddress());

        // Mint some tokens for testing
        await tokenA.mint(user1.address, ethers.parseEther("2000000"));
        await tokenA.mint(user2.address, ethers.parseEther("2000000"));

        // Transfer some tokens to the staking contract for rewards
        await tokenA.transfer(await stakingContract.getAddress(), ethers.parseEther("1000000"));
    });

    it("Should allow users to stake tokens", async function () {
        const stakeAmount = ethers.parseEther("1000");

        await tokenA.connect(user1).approve(await stakingContract.getAddress(), stakeAmount);
        await stakingContract.connect(user1).deposit(stakeAmount);

        const stake = await stakingContract.stakes(user1.address);
        expect(stake.amount).to.equal(stakeAmount);
    });

    it("Should mint NFT when staking over 1M tokens", async function () {
        const stakeAmount = ethers.parseEther("1000000");

        await tokenA.connect(user1).approve(await stakingContract.getAddress(), stakeAmount);
        await stakingContract.connect(user1).deposit(stakeAmount);

        const nftBalance = await nftCertificate.balanceOf(user1.address);
        expect(nftBalance).to.equal(1);
    });

    it("Should not allow withdrawal before lock period ends", async function () {
        const stakeAmount = ethers.parseEther("1000");

        await tokenA.connect(user1).approve(await stakingContract.getAddress(), stakeAmount);
        await stakingContract.connect(user1).deposit(stakeAmount);

        await expect(stakingContract.connect(user1).withdraw(stakeAmount))
            .to.be.revertedWith("Tokens are still locked");
    });

    it("Should allow withdrawal after lock period", async function () {
        const stakeAmount = ethers.parseEther("1000");

        await tokenA.connect(user1).approve(await stakingContract.getAddress(), stakeAmount);
        await stakingContract.connect(user1).deposit(stakeAmount);

        // Fast forward time
        await ethers.provider.send("evm_increaseTime", [300]); // 5 minutes
        await ethers.provider.send("evm_mine");

        const [withdrawableAmount] = await stakingContract.getWithdrawableAmount(user1.address);
        console.log("Withdrawable amount:", ethers.formatEther(withdrawableAmount));

        const userStake = await stakingContract.stakes(user1.address);
        console.log("User stake before withdrawal:", {
            amount: ethers.formatEther(userStake.amount),
            timestamp: userStake.timestamp.toString(),
            lockEndTime: userStake.lockEndTime.toString(),
            lastClaimTime: userStake.lastClaimTime.toString(),
            pendingRewards: ethers.formatEther(userStake.pendingRewards)
        });

        await expect(stakingContract.connect(user1).withdraw(withdrawableAmount))
            .to.not.be.reverted;

        const stakeAfter = await stakingContract.stakes(user1.address);
        expect(stakeAfter.amount).to.equal(0);
    });

    it("Should calculate and distribute rewards correctly", async function () {
        const stakeAmount = ethers.parseEther("1000");

        await tokenA.connect(user1).approve(await stakingContract.getAddress(), stakeAmount);
        await stakingContract.connect(user1).deposit(stakeAmount);

        // Fast forward time
        await ethers.provider.send("evm_increaseTime", [86400]); // 1 day
        await ethers.provider.send("evm_mine");

        const [, pendingReward] = await stakingContract.getWithdrawableAmount(user1.address);

        // Expected reward for 1 day at 8% APR
        const expectedReward = stakeAmount * BigInt(8) * BigInt(86400) / (BigInt(100) * BigInt(365) * BigInt(86400));

        expect(pendingReward).to.be.closeTo(expectedReward, ethers.parseEther("0.01"));
    });
});