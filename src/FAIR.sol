// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title FAIR Governance Token
 * @notice ERC20 token with voting capabilities for FairDAO governance
 * @dev Minting is restricted to AMM and Claim contracts. Has a fixed max supply.
 */
contract FAIR is ERC20, ERC20Permit, ERC20Votes, Ownable {
    address public amm;
    address public claimContract;

    uint256 public constant MAX_SUPPLY = 1_000_000 * 1e18;

    event AMMSet(address indexed amm);
    event ClaimContractSet(address indexed claimContract);
    event Burn(address indexed account, uint256 amount);

    error AlreadySet();
    error Unauthorized();
    error ZeroAddress();
    error SupplyExceeded();

    constructor(address initialOwner)
        ERC20("FAIR Governance Token", "FAIR")
        ERC20Permit("FAIR Governance Token")
        Ownable(initialOwner)
    {
        if (initialOwner == address(0)) revert ZeroAddress();
    }

    /// @notice Set the AMM contract address (one-time only)
    /// @param _amm Address of the FairAMM contract
    function setAMM(address _amm) external onlyOwner {
        if (amm != address(0)) revert AlreadySet();
        if (_amm == address(0)) revert ZeroAddress();
        amm = _amm;
        emit AMMSet(_amm);
    }

    /// @notice Set the claim contract address (one-time only)
    /// @param _claimContract Address of the FairClaim contract
    function setClaimContract(address _claimContract) external onlyOwner {
        if (claimContract != address(0)) revert AlreadySet();
        if (_claimContract == address(0)) revert ZeroAddress();
        claimContract = _claimContract;
        emit ClaimContractSet(_claimContract);
    }

    /// @notice Mint new FAIR tokens (restricted to AMM and Claim contracts)
    /// @param to Recipient address
    /// @param amount Amount to mint
    function mint(address to, uint256 amount) external {
        if (msg.sender != claimContract && msg.sender != amm) revert Unauthorized();
        if (totalSupply() + amount > MAX_SUPPLY) revert SupplyExceeded();
        _mint(to, amount);
    }

    /// @notice Burn FAIR tokens from caller's balance
    /// @param amount Amount to burn
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        emit Burn(msg.sender, amount);
    }

    /// @notice Burn FAIR tokens from another address (restricted to AMM)
    /// @dev Only AMM can burn from others. For burning from self, no approval needed.
    /// @param from Address to burn from
    /// @param amount Amount to burn
    function burnFrom(address from, uint256 amount) external {
        if (msg.sender != amm) revert Unauthorized();
        if (from != msg.sender) {
            _spendAllowance(from, msg.sender, amount);
        }
        _burn(from, amount);
        emit Burn(from, amount);
    }

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function nonces(address owner) public view override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }
}
