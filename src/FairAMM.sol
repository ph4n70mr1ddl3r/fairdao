// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./FAIR.sol";

/**
 * @title FairAMM
 * @notice Automated Market Maker for FAIR/ETH trading pair
 * @dev Uses constant product formula (x*y=k) with 0.3% swap fee.
 *      33% of fees go to dev, 67% stay in pool (as ETH) or are burned (FAIR).
 */
contract FairAMM is ReentrancyGuard, Ownable {
    FAIR public immutable fairToken;
    address public immutable deployer;
    address public claimContract;
    
    uint256 public ethBalance;
    uint256 public fairBalance;
    
    uint256 public constant SWAP_FEE_BASIS_POINTS = 30;
    uint256 public constant FEE_SHARE = 33;
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    
    uint256 public totalFeesToDev;
    uint256 public totalFairsBurned;
    
    event Swap(address indexed sender, bool ethIn, uint256 amountIn, uint256 amountOut, uint256 fee);
    event Donate(address indexed sender, uint256 ethAmount);
    event FeesCollected(uint256 devFee, uint256 burnAmount);
    event ClaimContractSet(address indexed claimContract);
    event LiquidityAdded(address indexed sender, uint256 amount);
    event ETHRescued(uint256 amount);
    event TokensRescued(address indexed token, uint256 amount);
    
    error NoLiquidity();
    error InsufficientOutput();
    error InvalidAmount();
    error Unauthorized();
    error AlreadySet();
    error ZeroAddress();
    
    constructor(address _fairToken, address _deployer, address initialOwner) Ownable(initialOwner) {
        if (_fairToken == address(0) || _deployer == address(0) || initialOwner == address(0)) revert ZeroAddress();
        fairToken = FAIR(_fairToken);
        deployer = _deployer;
    }
    
    function setClaimContract(address _claimContract) external onlyOwner {
        if (claimContract != address(0)) revert AlreadySet();
        if (_claimContract == address(0)) revert ZeroAddress();
        claimContract = _claimContract;
        emit ClaimContractSet(_claimContract);
    }
    
    function donate() external payable nonReentrant {
        if (msg.value == 0) revert InvalidAmount();
        ethBalance += msg.value;
        emit Donate(msg.sender, msg.value);
    }
    
    /// @notice Swap ETH for FAIR tokens
    /// @param amountOutMin Minimum FAIR tokens to receive (slippage protection)
    /// @return amountOut Actual amount of FAIR tokens received
    function swapEthForFair(uint256 amountOutMin) external payable nonReentrant returns (uint256 amountOut) {
        uint256 _ethBalance = ethBalance;
        uint256 _fairBalance = fairBalance;
        
        if (msg.value == 0) revert InvalidAmount();
        if (_fairBalance < MINIMUM_LIQUIDITY) revert NoLiquidity();
        
        uint256 fee = (msg.value * SWAP_FEE_BASIS_POINTS) / BASIS_POINTS;
        uint256 amountInAfterFee;
        unchecked {
            amountInAfterFee = msg.value - fee;
        }
        
        uint256 k = _ethBalance * _fairBalance;
        uint256 newEthBalance = _ethBalance + amountInAfterFee;
        uint256 newFairBalance = (k / newEthBalance) + 1;
        
        amountOut = _fairBalance - newFairBalance;
        if (amountOut < amountOutMin) revert InsufficientOutput();
        if (amountOut > _fairBalance) revert InsufficientOutput();
        if (amountOut > fairToken.balanceOf(address(this))) revert InsufficientOutput();
        
        uint256 devFee = (fee * FEE_SHARE) / 100;
        uint256 poolFee;
        unchecked {
            poolFee = fee - devFee;
        }
        
        ethBalance = newEthBalance + poolFee;
        fairBalance = newFairBalance;
        
        _sendDevFee(devFee);
        require(fairToken.transfer(msg.sender, amountOut), "Transfer failed");
        
        emit Swap(msg.sender, true, msg.value, amountOut, fee);
    }
    
    /// @notice Swap FAIR tokens for ETH
    /// @param amountIn Amount of FAIR tokens to swap
    /// @param amountOutMin Minimum ETH to receive (slippage protection)
    /// @return amountOut Actual amount of ETH received
    function swapFairForEth(uint256 amountIn, uint256 amountOutMin) external nonReentrant returns (uint256 amountOut) {
        uint256 _ethBalance = ethBalance;
        uint256 _fairBalance = fairBalance;
        
        if (amountIn == 0) revert InvalidAmount();
        if (_ethBalance < MINIMUM_LIQUIDITY) revert NoLiquidity();
        
        uint256 fee = (amountIn * SWAP_FEE_BASIS_POINTS) / BASIS_POINTS;
        uint256 amountInAfterFee;
        unchecked {
            amountInAfterFee = amountIn - fee;
        }
        
        uint256 k = _ethBalance * _fairBalance;
        uint256 newFairBalance = _fairBalance + amountInAfterFee;
        uint256 newEthBalance = (k / newFairBalance) + 1;
        
        amountOut = _ethBalance - newEthBalance;
        if (amountOut < amountOutMin) revert InsufficientOutput();
        if (amountOut > address(this).balance) revert InsufficientOutput();
        
        uint256 burnAmount = (fee * FEE_SHARE) / 100;
        uint256 poolFee;
        unchecked {
            poolFee = fee - burnAmount;
        }
        
        fairBalance = newFairBalance + poolFee;
        ethBalance = newEthBalance;
        
        require(fairToken.transferFrom(msg.sender, address(this), amountIn), "TransferFrom failed");
        _burnFees(burnAmount);
        
        (bool success, ) = payable(msg.sender).call{value: amountOut}("");
        require(success, "ETH transfer failed");
        
        emit Swap(msg.sender, false, amountIn, amountOut, fee);
    }
    
    function _sendDevFee(uint256 devFee) internal {
        if (devFee > 0) {
            (bool success, ) = payable(deployer).call{value: devFee}("");
            require(success, "Dev fee transfer failed");
            totalFeesToDev += devFee;
            emit FeesCollected(devFee, 0);
        }
    }
    
    function _burnFees(uint256 burnAmount) internal {
        if (burnAmount > 0) {
            fairToken.burnFrom(address(this), burnAmount);
            totalFairsBurned += burnAmount;
            emit FeesCollected(0, burnAmount);
        }
    }
    
    function addFairLiquidity(uint256 amount) external {
        if (msg.sender != claimContract && msg.sender != owner()) revert Unauthorized();
        uint256 newFairBalance = fairBalance + amount;
        require(fairToken.balanceOf(address(this)) >= newFairBalance, "Insufficient token balance");
        fairBalance = newFairBalance;
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
    
    /// @notice Rescue excess ETH sent to contract
    /// @param amount Amount of ETH to rescue
    function rescueETH(uint256 amount) external onlyOwner {
        uint256 excess = address(this).balance - ethBalance;
        require(amount <= excess, "Cannot rescue tracked ETH");
        (bool success, ) = payable(owner()).call{value: amount}("");
        require(success, "Rescue failed");
        emit ETHRescued(amount);
    }
    
    /// @notice Rescue excess tokens sent to contract
    /// @param token Address of token to rescue
    /// @param amount Amount of tokens to rescue
    function rescueTokens(address token, uint256 amount) external onlyOwner {
        if (token == address(fairToken)) {
            uint256 excess = fairToken.balanceOf(address(this)) - fairBalance;
            require(amount <= excess, "Cannot rescue tracked FAIR");
        }
        require(IERC20(token).transfer(owner(), amount), "Transfer failed");
        emit TokensRescued(token, amount);
    }

    receive() external payable nonReentrant {
        if (msg.value == 0) revert InvalidAmount();
        ethBalance += msg.value;
        emit Donate(msg.sender, msg.value);
    }
}
