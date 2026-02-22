// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FAIR is ERC20, ERC20Permit, ERC20Votes, Ownable {
    address public amm;
    address public claimContract;
    
    event AMMSet(address indexed amm);
    event ClaimContractSet(address indexed claimContract);
    event Burn(address indexed account, uint256 amount);
    
    error AlreadySet();
    error Unauthorized();
    error ZeroAddress();
    
    constructor(address initialOwner) 
        ERC20("FAIR Governance Token", "FAIR") 
        ERC20Permit("FAIR Governance Token")
        Ownable(initialOwner) 
    {
        if (initialOwner == address(0)) revert ZeroAddress();
    }
    
    function setAMM(address _amm) external onlyOwner {
        if (amm != address(0)) revert AlreadySet();
        if (_amm == address(0)) revert ZeroAddress();
        amm = _amm;
        emit AMMSet(_amm);
    }
    
    function setClaimContract(address _claimContract) external onlyOwner {
        if (claimContract != address(0)) revert AlreadySet();
        if (_claimContract == address(0)) revert ZeroAddress();
        claimContract = _claimContract;
        emit ClaimContractSet(_claimContract);
    }
    
    function mint(address to, uint256 amount) external {
        if (msg.sender != claimContract && msg.sender != amm) revert Unauthorized();
        _mint(to, amount);
    }
    
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        emit Burn(msg.sender, amount);
    }
    
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
