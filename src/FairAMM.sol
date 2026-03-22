// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./FAIR.sol";

/**
 * @title FairAMM
 * @notice Automated Market Maker for FAIR/ETH trading pair
 * @dev Uses constant product formula (x*y=k) with 0.3% swap fee.
 *      33% of fees go to dev, 67% stay in pool (as ETH) or are burned (FAIR).
 *      Features:
 *      - ETH -> FAIR swaps with slippage protection
 *      - FAIR -> ETH swaps with slippage protection
 *      - Donation mechanism for adding ETH liquidity
 *      - Rescue functions for recovering excess tokens
 */
contract FairAMM is ReentrancyGuard, Ownable {
    /// @notice The FAIR token contract
    FAIR public immutable fairToken;
    /// @notice Address receiving developer fees
    address public immutable deployer;
    /// @notice Address of the claim contract (set once)
    address public claimContract;

    /// @notice Tracked ETH balance in the pool
    uint256 public ethBalance;
    /// @notice Tracked FAIR balance in the pool
    uint256 public fairBalance;

    /// @notice Swap fee in basis points (30 = 0.3%)
    uint256 public constant SWAP_FEE_BASIS_POINTS = 30;
    /// @notice Share of fees going to developer (33%)
    uint256 public constant FEE_SHARE = 33;
    /// @notice Basis points denominator
    uint256 public constant BASIS_POINTS = 10000;
    /// @notice Minimum liquidity threshold
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    /// @notice Total ETH fees sent to developer
    uint256 public totalFeesToDev;
    /// @notice Total FAIR tokens burned from fees
    uint256 public totalFairsBurned;

    /// @notice Emitted on successful swap
    event Swap(address indexed sender, bool ethIn, uint256 amountIn, uint256 amountOut, uint256 fee);
    /// @notice Emitted when ETH is donated to the pool
    event Donate(address indexed sender, uint256 ethAmount);
    /// @notice Emitted when fees are collected
    event FeesCollected(uint256 devFee, uint256 burnAmount);
    /// @notice Emitted when claim contract is set
    event ClaimContractSet(address indexed claimContract);
    /// @notice Emitted when FAIR liquidity is added
    event LiquidityAdded(address indexed sender, uint256 amount);
    /// @notice Emitted when excess ETH is rescued
    event ETHRescued(uint256 amount);
    /// @notice Emitted when excess tokens are rescued
    event TokensRescued(address indexed token, uint256 amount);

    /// @notice Thrown when pool has no liquidity
    error NoLiquidity();
    /// @notice Thrown when output amount is less than minimum
    error InsufficientOutput();
    /// @notice Thrown when amount is zero
    error InvalidAmount();
    /// @notice Thrown when unauthorized caller
    error Unauthorized();
    /// @notice Thrown when trying to set already-set address
    error AlreadySet();
    /// @notice Thrown when zero address provided
    error ZeroAddress();
    /// @notice Thrown when ETH transfer fails
    error ETHTransferFailed();
    /// @notice Thrown when token transfer fails
    error TokenTransferFailed();
    /// @notice Thrown when trying to rescue more than excess
    error InsufficientExcess();
    /// @notice Thrown when token balance is insufficient for burn
    error InsufficientBurnBalance();
    /// @notice Thrown when token balance is insufficient
    error InsufficientTokenBalance();

    /// @notice Constructor initializes the AMM
    /// @param _fairToken Address of the FAIR token contract
    /// @param _deployer Address to receive developer fees
    /// @param initialOwner Address that will own the contract
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

    /// @notice Donate ETH to the AMM pool
    /// @dev Increases ETH liquidity without receiving FAIR
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
        if (amountOut > fairToken.balanceOf(address(this))) revert InsufficientOutput();

        uint256 devFee = (fee * FEE_SHARE) / 100;
        uint256 poolFee;
        unchecked {
            poolFee = fee - devFee;
        }

        ethBalance = newEthBalance + poolFee;
        fairBalance = newFairBalance;

        _sendDevFee(devFee);
        if (!fairToken.transfer(msg.sender, amountOut)) revert TokenTransferFailed();

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

        if (!fairToken.transferFrom(msg.sender, address(this), amountIn)) revert TokenTransferFailed();
        _burnFees(burnAmount);

        (bool success,) = payable(msg.sender).call{value: amountOut}("");
        if (!success) revert ETHTransferFailed();

        emit Swap(msg.sender, false, amountIn, amountOut, fee);
    }

    /// @dev Sends developer fee in ETH to deployer address
    function _sendDevFee(uint256 devFee) internal {
        if (devFee > 0) {
            (bool success,) = payable(deployer).call{value: devFee}("");
            if (!success) revert ETHTransferFailed();
            totalFeesToDev += devFee;
            emit FeesCollected(devFee, 0);
        }
    }

    /// @dev Burns FAIR tokens from the pool as part of fee distribution
    function _burnFees(uint256 burnAmount) internal {
        if (burnAmount > 0) {
            if (fairToken.balanceOf(address(this)) < burnAmount) revert InsufficientBurnBalance();
            fairToken.burnFrom(address(this), burnAmount);
            totalFairsBurned += burnAmount;
            emit FeesCollected(0, burnAmount);
        }
    }

    /// @notice Add FAIR liquidity to the pool
    /// @dev Restricted to claim contract and owner. Tokens must already be in contract.
    /// @param amount Amount of FAIR to add to tracked balance
    function addFairLiquidity(uint256 amount) external {
        if (msg.sender != claimContract && msg.sender != owner()) revert Unauthorized();
        if (amount == 0) revert InvalidAmount();
        uint256 newFairBalance;
        unchecked {
            newFairBalance = fairBalance + amount;
        }
        if (fairToken.balanceOf(address(this)) < newFairBalance) revert InsufficientTokenBalance();
        fairBalance = newFairBalance;
        emit LiquidityAdded(msg.sender, amount);
    }

    /// @notice Calculate expected output amount for a swap
    /// @param ethIn True if swapping ETH for FAIR, false for FAIR to ETH
    /// @param amountIn Input amount
    /// @return Expected output amount
    function getAmountOut(bool ethIn, uint256 amountIn) external view returns (uint256) {
        if (amountIn == 0) return 0;

        uint256 fee = (amountIn * SWAP_FEE_BASIS_POINTS) / BASIS_POINTS;
        uint256 amountInAfterFee;
        unchecked {
            amountInAfterFee = amountIn - fee;
        }

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

    /// @notice Check if the AMM has ETH liquidity
    /// @return True if ETH balance > 0
    function hasLiquidity() external view returns (bool) {
        return ethBalance > 0;
    }

    /// @notice Rescue excess ETH sent to contract
    /// @param amount Amount of ETH to rescue
    function rescueETH(uint256 amount) external onlyOwner {
        uint256 excess = address(this).balance - ethBalance;
        if (amount > excess) revert InsufficientExcess();
        (bool success,) = payable(owner()).call{value: amount}("");
        if (!success) revert ETHTransferFailed();
        emit ETHRescued(amount);
    }

    /// @notice Rescue excess tokens sent to contract
    /// @param token Address of token to rescue
    /// @param amount Amount of tokens to rescue
    function rescueTokens(address token, uint256 amount) external onlyOwner {
        if (token == address(fairToken)) {
            uint256 excess = fairToken.balanceOf(address(this)) - fairBalance;
            if (amount > excess) revert InsufficientExcess();
        }
        if (!IERC20(token).transfer(owner(), amount)) revert TokenTransferFailed();
        emit TokensRescued(token, amount);
    }

    receive() external payable {
        if (msg.value == 0) revert InvalidAmount();
        ethBalance += msg.value;
        emit Donate(msg.sender, msg.value);
    }
}
