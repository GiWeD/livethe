// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/ILiVeNFT.sol";

contract Manager is OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public underlying;
    uint256 public MAXTIME;
    uint256 public WEEK;

    address public feeManager;
    address public strategy;
    address public liVeNFT;

    constructor() public {}

    function initialize(
        address _strategy,
        address _liquidVe,
        address _underlying,
        uint _lockingYear   // eg.: crv = 4, lqdr = 2
    ) public initializer {
        __Ownable_init();
        feeManager = msg.sender;
        strategy = _strategy;

        liVeNFT = _liquidVe;

        MAXTIME = _lockingYear * 364 * 86400;
        WEEK = 7 * 86400;
        underlying = _underlying;
    }

    function initialLock() public {
        require(msg.sender == owner() || msg.sender == address(this), "!auth");

        uint256 unlockAt = block.timestamp + MAXTIME;

        //release old lock if exists
        IStrategy(strategy).release();
        //create new lock
        uint256 _strategyBalance = IERC20(underlying).balanceOf(strategy);
        IStrategy(strategy).createLock(_strategyBalance, unlockAt);
    }

    //lock more 'underlying into the inSpirit contract
    function _increaseAmount(uint256 _amount) internal {
        IERC20(underlying).safeTransfer(strategy, _amount);

        uint256 _underlyingLocked = IStrategy(strategy).balanceOfVeNFT();

        if (_underlyingLocked > 0) {
            //increase amount
            IStrategy(strategy).increaseAmount(_amount);
        } else {
            initialLock();
        }
    }

    function _deposit(uint256 _amount) internal {
        require(_amount > 0, "!>0");
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), _amount);
        _increaseAmount(_amount);
        ILiVeNFT(liVeNFT).mint(msg.sender, _amount);
    }

    //deposit 'underlying' for liVeNFT
    function deposit(uint256 _amount) public {
        _deposit(_amount);        
    }  

    function depositAll() external {
        uint256 _amount = IERC20(underlying).balanceOf(msg.sender);
        _deposit(_amount);
    }
}