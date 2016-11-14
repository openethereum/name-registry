//! Certifier contract, taken from ethcore/sms-verification
//! By Gav Wood (Ethcore), 2016.
//! Released under the Apache Licence 2.

pragma solidity ^0.4.0;

contract Certifier {
    event Confirmed(address indexed who);
    event Revoked(address indexed who);
    function certified(address _who) constant returns (bool);
    function get(address _who, string _field) constant returns (bytes32) {}
    function getAddress(address _who, string _field) constant returns (address) {}
    function getUint(address _who, string _field) constant returns (uint) {}
}
