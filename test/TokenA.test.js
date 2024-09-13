const { expect } = require("chai");
const { ethers } = require("hardhat");
const { parseEther } = ethers;
const hre = require("hardhat");

describe("TokenA", function () {
    let tokenA;
    let owner;
    let user;

    beforeEach(async function () {
        [owner, user] = await ethers.getSigners();

        const TokenA = await ethers.getContractFactory("TokenA");
        tokenA = await TokenA.deploy(parseEther("1000000"));
        await tokenA.waitForDeployment();
    });

    it("Should have correct initial supply", async function () {
        const totalSupply = await tokenA.totalSupply();
        expect(totalSupply).to.equal(parseEther("1000000"));
    });

    it("Should allow users to use faucet", async function () {
        await tokenA.connect(user).faucet();

        const balance = await tokenA.balanceOf(user.address);
        expect(balance).to.equal(parseEther("1000000"));
    });

    it("Should not allow faucet use before cooldown period", async function () {
        await tokenA.connect(user).faucet();

        await expect(tokenA.connect(user).faucet())
            .to.be.revertedWith("Faucet cooldown not expired");
    });

    it("Should allow faucet use after cooldown period", async function () {
        await tokenA.connect(user).faucet();

        
        await ethers.provider.send("evm_increaseTime", [15]);
        await ethers.provider.send("evm_mine", []);

        await tokenA.connect(user).faucet();

        const balance = await tokenA.balanceOf(user.address);
        expect(balance).to.equal(parseEther("2000000"));
    });

    it("Should allow owner to mint tokens", async function () {
        await tokenA.mint(user.address, parseEther("1000"));

        const balance = await tokenA.balanceOf(user.address);
        expect(balance).to.equal(parseEther("1000"));
    });

    it("Should not allow non-owners to mint tokens", async function () {
        await expect(tokenA.connect(user).mint(user.address, parseEther("1000")))
            .to.be.revertedWithCustomError(tokenA, "OwnableUnauthorizedAccount");
    });
});