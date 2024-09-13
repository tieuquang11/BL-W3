

const hre = require("hardhat");

async function main() {
    const [deployer] = await hre.ethers.getSigners();

    console.log("Deploying contracts with the account:", deployer.address);

    // Deploy TokenA
    const TokenA = await hre.ethers.getContractFactory("TokenA");
    const initialSupply = hre.ethers.parseEther("1000000000"); // 1 billion tokens
    const tokenA = await TokenA.deploy(initialSupply);
    await tokenA.waitForDeployment();
    console.log("TokenA deployed to:", await tokenA.getAddress());

    // Deploy NFTCertificate
    const NFTCertificate = await hre.ethers.getContractFactory("NFTCertificate");
    const nftCertificate = await NFTCertificate.deploy();
    await nftCertificate.waitForDeployment();
    console.log("NFTCertificate deployed to:", await nftCertificate.getAddress());

    // Deploy StakingContract
    const StakingContract = await hre.ethers.getContractFactory("StakingContract");
    const stakingContract = await StakingContract.deploy(await tokenA.getAddress(), await nftCertificate.getAddress());
    await stakingContract.waitForDeployment();
    console.log("StakingContract deployed to:", await stakingContract.getAddress());

    // Transfer ownership of NFTCertificate to StakingContract
    await nftCertificate.transferOwnership(await stakingContract.getAddress());
    console.log("NFTCertificate ownership transferred to StakingContract");

    // Approve StakingContract to spend TokenA
    const approveAmount = hre.ethers.parseEther("1000000000"); // Approve all tokens
    await tokenA.approve(await stakingContract.getAddress(), approveAmount);
    console.log("TokenA approved StakingContract to spend", hre.ethers.formatEther(approveAmount), "tokens");

    

    console.log("Deployment and setup completed!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });