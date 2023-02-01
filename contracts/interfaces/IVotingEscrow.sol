// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;
interface IVotingEscrow {

    function token() external view returns (address);
    function create_lock(uint _value, uint _lock_duration) external returns(uint);
    function withdraw(uint _tokenId) external;
    function increase_amount(uint _tokenId, uint _value) external;
    function increase_unlock_time(uint _tokenId, uint _lock_duration) external ;
    function balanceOfNFT(uint _id) external view returns (uint);
    function balanceOf(address _owner) external view returns (uint);
}
