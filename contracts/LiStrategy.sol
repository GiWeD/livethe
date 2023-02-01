// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./interfaces/IVotingEscrow.sol";
import "./interfaces/IVoter.sol";
import "./interfaces/IRewardsDistributor.sol";


contract LiStrategy is OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    struct lastVotes{
        address[] pairs;
        uint256[] weights;
    }
    
    address public veNFT;
    address public underlying;
    address public liManager;
    address public voter;
    address public extension;
    address public feeManager;
    address public rewardDistro;

    lastVotes public votes;

    mapping(address => bool) isBoostStrategy;
    mapping(address => bool) isAllowedVoter;

    uint256 public tokenId;
    uint256 public MAX_TIME;


    event UpdateExtension(address oldExtenstion, address newExtestion);



    constructor() public {}

    function initialize(
        address _underlying,
        address _veNFT,
        address _voter,
        address _xLQDRTreasury,
        address _feemanager,
        uint256 _feeGauge,
        uint256 _feeStaking,
        uint256 _feeX,
        uint _lockingYear   // eg.: crv = 4, lqdr = 2
    ) public initializer {
        __Ownable_init();

        underlying = _underlying;
        veNFT = _veNFT;
        require(_underlying == IVotingEscrow(veNFT).token(), 'not same token');
        
        voter = _voter;

        feeManager = _feemanager;

        MAX_TIME = _lockingYear * 364 * 86400;
    }

    modifier restricted {
        require(msg.sender == owner() || msg.sender == liManager, "Auth failed");
        _;
    }

    modifier ownerOrBoostStrategy {
        require(msg.sender == owner() || isBoostStrategy[msg.sender], "Permission denied");
        _;
    }

    modifier ownerOrAllowedVoter {
        require(msg.sender == owner() || isAllowedVoter[msg.sender], "Permission denied");
        _;
    }

    modifier onlyExtension {
        require(msg.sender == extension, "Auth failed");
        _;
    }

    /*
        -------------------
        OWNER SETTINGS
        -------------------
    */

    function setExtension(address _newExtension) external onlyOwner {
		address _oldExtension = extension;
		extension = _newExtension;
		emit UpdateExtension(_oldExtension, _newExtension);
	}

    function setVoter(address _voter) external onlyOwner {
        require(_voter != address(0), 'addr 0');
        voter = _voter;
    }

    function setRewardDistributor(address _rewardDistro) external onlyOwner {
        require(_rewardDistro != address(0), 'addr 0');
        rewardDistro = _rewardDistro;
    }

    function setManager(address _manager) external onlyOwner {
        require(_manager != address(0), 'addr 0');
        liManager = _manager;
    }

    function setTokenId(uint _tokenId) external onlyOwner {
        tokenId = _tokenId;
    }


    function whitelistBoostStrategy(address _strategy) external onlyOwner {
        isBoostStrategy[_strategy] = true;
    }

    function blacklistBoostStrategy(address _strategy) external onlyOwner {
        isBoostStrategy[_strategy] = false;
    }

    function whitelistVoter(address _voter) external onlyOwner {
        isAllowedVoter[_strategy] = true;
    }

    function blacklistVoter(address _voter) external onlyOwner {
        isAllowedVoter[_strategy] = false;
    }

    /*  
        -------------------
        VENFT MANAGMENT
        -------------------
    */

    function createLock(uint256 _amount, uint256 _unlockTime) external restricted {
        uint256 _balance = IERC20(underlying).balanceOf(address(this));
        require(_amount <= _balance, "Amount exceeds balance");
        IERC20(underlying).safeApprove(veNFT, 0);
        IERC20(underlying).safeApprove(veNFT, _amount);
        IVotingEscrow(veNFT).create_lock(_amount, _unlockTime);
    }

    function release() external restricted {
        IVotingEscrow(veNFT).withdraw(tokenId);
    }

    function increaseAmount(uint256 _amount) external restricted {
        uint256 _balance = IERC20(underlying).balanceOf(address(this));
        require(_amount <= _balance, "Amount exceeds underlying balance");
        IERC20(underlying).safeApprove(veNFT, 0);
        IERC20(underlying).safeApprove(veNFT, _amount);
        IVotingEscrow(veNFT).increase_amount(tokenId, _amount);
    }

    function increaseTime(uint256 _unlockTime) external restricted {
        IVotingEscrow(veNFT).increase_unlock_time(tokenId, _unlockTime);
    }

    function increaseTimeMax() external ownerOrBoostStrategy {
        uint unlock_time = (block.timestamp + _lock_duration) / WEEK * WEEK;
        IVotingEscrow(veNFT).increase_unlock_time(tokenId, _unlockTime);
    }

    function balanceOfVeNFT() external view returns (uint256) {
        return IVotingEscrow(veNFT).balanceOfNFT(tokenId);
    }


    /*  
        -------------------
        VOTING AND CLAIMING
        -------------------
    */


    function claimBribe(address[] memory _bribes, address[][] memory _tokens) external ownerOrBoostStrategy {
        IVoter(voter).claimBribes(_bribes, _tokens, tokenId);
        uint256 i = 0;
        uint256 k = 0;
        uint256 _len1 = _bribes.length;
        uint256 _len2;
        uint256 _amount = 0;
        address _token;
        for(i; i < _len1; i++){
            _len2 = _tokens[i].length;
            for(k = 0; k < _len2; k++){
                _token = _tokens[i][k];
                _amount = IERC20(_token).balanceOf(address(this));
                if(_amount > 0){
                    IERC20(_token).safeTransfer(feeManager, _amount);
                }
            }
        }
    }

    function claimFees(address[] memory _fees, address[][] memory _tokens) external ownerOrBoostStrategy {
        IVoter(voter).claimFees(_fees, _tokens, tokenId);
        uint256 i = 0;
        uint256 k = 0;
        uint256 _len1 = _fees.length;
        uint256 _len2;
        uint256 _amount = 0;
        address _token;
        for(i; i < _len1; i++){
            _len2 = _tokens[i].length;
            for(k = 0; k < _len2; k++){
                _token = _tokens[i][k];
                _amount = IERC20(_token).balanceOf(address(this));
                if(_amount > 0){
                    IERC20(_token).safeTransfer(feeManager, _amount);
                }
            }
        }
    }

    function claimRebase() external ownerOrBoostStrategy {
        IRewardsDistributor(rewardDistro).claim(tokenId);
    }


    function vote(address[] calldata _pool, uint256[] calldata _weights) external ownerOrAllowedVoter {
        require(_pool.length == _weights.length, "Token length doesn't match");
        uint256 _length = _pool.length;
        uint256 i = 0;
        for (i; i < _length; i++) {
            IVoter(voter).vote(tokenId, _pool[i], _weights[i]);
        }

        lastVotes memory _votes;
        _votes.pairs = new address[](_length);
        _votes.pairs = _pool;

        _votes.weights = new uint[](_length);
        _votes.weights = _weights;

        votes = _votes;
    }

    
    function externalCall(address _target, bytes calldata _calldata) external payable onlyExtension returns (bool _success, bytes memory _resultdata){
        require(extension != address(0));
		return _target.call{value: msg.value}(_calldata);
	}


}