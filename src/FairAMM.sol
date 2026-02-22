// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./FAIR.sol";

contract FairAMM is ReentrancyGuard, Ownable {
    FAIR public immutable fairToken;
    address public immutable deployer;
    address public claimContract;
    
    uint256 public ethBalance;
    uint256 public fairBalance;
    
    uint256 public constant SWAP_FEE_BASIS_POINTS = 30;
    uint256 public constant DEV_FEE_SHARE = 10;
    uint256 public constant BURN_FEE_SHARE = 10;
    uint256 public constant BASIS_POINTS = 10000;
    
    uint256 public totalFeesToDev;
    uint256 public totalFairsBurned;
    
    event Swap(address indexed sender, bool ethIn, uint256 amountIn, uint256 amountOut, uint256 fee);
    event Donate(address indexed sender, uint256 ethAmount);
    event FeesCollected(uint256 devFee, uint256 burnAmount);
    event ClaimContractSet(address indexed claimContract);
    event LiquidityAdded(address indexed sender, uint256 amount);
    
    error NoLiquidity();
    error InsufficientOutput();
    error InvalidAmount();
    error Unauthorized();
    error AlreadySet();
    error ZeroAddress();
    
    constructor(address _fairToken, address _deployer, address initialOwner) Ownable(initialOwner) {
        if (_fairToken == address(0) || _deployer == address(0)) revert ZeroAddress();
        fairToken = FAIR(_fairToken);
        deployer = _deployer;
    }
    
    function setClaimContract(address _claimContract) external onlyOwner {
        if (claimContract != address(0)) revert AlreadySet();
        claimContract = _claimContract;
        emit ClaimContractSet(_claimContract);
    }
    
    function donate() external payable nonReentrant {
        if (msg.value == 0) revert InvalidAmount();
        ethBalance += msg.value;
        emit Donate(msg.sender, msg.value);
    }
    
    function swapEthForFair(uint256 amountOutMin) external payable nonReentrant returns (uint256 amountOut) {
        if (msg.value == 0) revert InvalidAmount();
        if (fairBalance == 0) revert NoLiquidity();
        
        uint256 fee = (msg.value * SWAP_FEE_BASIS_POINTS) / BASIS_POINTS;
        uint256 amountInAfterFee = msg.value - fee;
        
        uint256 k = ethBalance * fairBalance;
        uint256 newEthBalance = ethBalance + amountInAfterFee;
        uint256 newFairBalance = (k / newEthBalance) + 1;
        
        amountOut = fairBalance - newFairBalance;
        if (amountOut < amountOutMin) revert InsufficientOutput();
        if (amountOut > fairBalance) revert InsufficientOutput();
        
        uint256 poolFee = _distributeFees(fee, true);
        
        ethBalance = newEthBalance + poolFee;
        fairBalance = newFairBalance;
        
        require(fairToken.transfer(msg.sender, amountOut), "Transfer failed");
        
        emit Swap(msg.sender, true, msg.value, amountOut, fee);
    }
    
    function swapFairForEth(uint256 amountIn, uint256 amountOutMin) external nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert InvalidAmount();
        if (ethBalance == 0) revert NoLiquidity();
        
        uint256 fee = (amountIn * SWAP_FEE_BASIS_POINTS) / BASIS_POINTS;
        uint256 amountInAfterFee = amountIn - fee;
        
        uint256 k = ethBalance * fairBalance;
        uint256 newFairBalance = fairBalance + amountInAfterFee;
        uint256 newEthBalance = (k / newFairBalance) + 1;
        
        amountOut = ethBalance - newEthBalance;
        if (amountOut < amountOutMin) revert InsufficientOutput();
        if (amountOut > ethBalance) revert InsufficientOutput();
        if (amountOut > address(this).balance) revert InsufficientOutput();
        
        uint256 poolFee = _distributeFees(fee, false);
        
        fairBalance = newFairBalance + poolFee;
        ethBalance = newEthBalance;
        
        require(fairToken.transferFrom(msg.sender, address(this), amountIn), "TransferFrom failed");
        (bool success, ) = payable(msg.sender).call{value: amountOut}("");
        require(success, "ETH transfer failed");
        
        emit Swap(msg.sender, false, amountIn, amountOut, fee);
    }
    
    function _distributeFees(uint256 fee, bool isEthIn) internal returns (uint256 poolFee) {
        uint256 devFee = isEthIn ? (fee * DEV_FEE_SHARE) / 100 : 0;
        uint256 burnAmount = isEthIn ? 0 : (fee * BURN_FEE_SHARE) / 100;
        poolFee = fee - devFee - burnAmount;
        
        if (isEthIn) {
            (bool success, ) = payable(deployer).call{value: devFee}("");
            require(success, "Dev fee transfer failed");
            totalFeesToDev += devFee;
        } else {
            fairToken.burnFrom(address(this), burnAmount);
            totalFairsBurned += burnAmount;
        }
        
        emit FeesCollected(devFee, burnAmount);
    }
    
    function addFairLiquidity(uint256 amount) external {
        if (msg.sender != claimContract && msg.sender != owner()) revert Unauthorized();
        fairBalance += amount;
        emit LiquidityAdded(msg.sender, amount);
    }
    
    function getAmountOut(bool ethIn, uint256 amountIn) external view returns (uint256) {
        if (amountIn == 0) return 0;
        
        uint256 fee = (amountIn * SWAP_FEE_BASIS_POINTS) / BASIS_POINTS;
        uint256 amountInAfterFee = amountIn - fee;
        
        uint256 k = ethBalance * fairBalance;
        
        if (ethIn) {
            if (fairBalance == 0) return 0;
            uint256 newEthBalance = ethBalance + amountInAfterFee;
            uint256 newFairBalance = (k / newEthBalance) + 1;
            return fairBalance > newFairBalance ? fairBalance - newFairBalance : 0;
        } else {
            if (ethBalance == 0) return 0;
            uint256 newFairBalance = fairBalance + amountInAfterFee;
            uint256 newEthBalance = (k / newFairBalance) + 1;
            return ethBalance > newEthBalance ? ethBalance - newEthBalance : 0;
        }
    }
    
    function hasLiquidity() external view returns (bool) {
        return ethBalance > 0;
    }
    
    function rescueETH(uint256 amount) external onlyOwner {
        uint256 excess = address(this).balance - ethBalance;
        require(amount <= excess, "Cannot rescue tracked ETH");
        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "Rescue failed");
    }
    
    function rescueTokens(address token, uint256 amount) external onlyOwner {
        if (token == address(fairToken)) {
            uint256 excess = fairToken.balanceOf(address(this)) - fairBalance;
            require(amount <= excess, "Cannot rescue tracked FAIR");
        }
        require(IERC20(token).transfer(owner(), amount), "Transfer failed");
    }

    receive() external payable nonReentrant {
        if (msg.value > 0) {
            ethBalance += msg.value;
            emit Donate(msg.sender, msg.value);
        }
    }
}
