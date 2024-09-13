const { expect } = require("chai");
const { ethers } = require("hardhat");

const hre = require("hardhat");

describe("NFTCertificate", function () {
    let nftCertificate;
    let owner;
    let user;

    beforeEach(async function () {
        [owner, user] = await ethers.getSigners();

        const NFTCertificate = await ethers.getContractFactory("NFTCertificate");
        nftCertificate = await NFTCertificate.deploy();
        await nftCertificate.waitForDeployment();
    });

    it("Should allow owner to mint NFTs", async function () {
        await nftCertificate.mint(user.address);

        const balance = await nftCertificate.balanceOf(user.address);
        expect(balance).to.equal(1);
    });

    it("Should not allow non-owners to mint NFTs", async function () {
        await expect(nftCertificate.connect(user).mint(user.address))
            .to.be.revertedWithCustomError(nftCertificate, "OwnableUnauthorizedAccount");
    });

    it("Should increment token ID for each mint", async function () {
        await nftCertificate.mint(user.address);
        await nftCertificate.mint(user.address);

        const balance = await nftCertificate.balanceOf(user.address);
        expect(balance).to.equal(2);

        expect(await nftCertificate.ownerOf(0)).to.equal(user.address);
        expect(await nftCertificate.ownerOf(1)).to.equal(user.address);
    });
});