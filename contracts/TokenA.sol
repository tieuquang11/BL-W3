// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenA is ERC20, Ownable {
    uint256 public constant FAUCET_AMOUNT = 1_000_000 * 1e18; // 1M tokens
    uint256 public constant FAUCET_COOLDOWN = 15 seconds;

    mapping(address => uint256) public lastFaucetTimestamp;

    constructor(uint256 initialSupply) ERC20("TokenA", "TKA") Ownable(msg.sender) {
        _mint(msg.sender, initialSupply);
    }

    function faucet() external {
        require(block.timestamp >= lastFaucetTimestamp[msg.sender] + FAUCET_COOLDOWN, "Faucet cooldown not expired");
        
        lastFaucetTimestamp[msg.sender] = block.timestamp;
        _mint(msg.sender, FAUCET_AMOUNT);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}