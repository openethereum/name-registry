//! The simple registry contract.
//!
//! Copyright 2016 Gavin Wood, Parity Technologies Ltd.
//!
//! Licensed under the Apache License, Version 2.0 (the "License");
//! you may not use this file except in compliance with the License.
//! You may obtain a copy of the License at
//!
//!	    http://www.apache.org/licenses/LICENSE-2.0
//!
//! Unless required by applicable law or agreed to in writing, software
//! distributed under the License is distributed on an "AS IS" BASIS,
//! WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//! See the License for the specific language governing permissions and
//! limitations under the License.

pragma solidity ^0.4.24;

import "./Owned.sol";
import "./Registry.sol";


contract SimpleRegistry is Owned, MetadataRegistry, OwnerRegistry, ReverseRegistry {
	struct Entry {
		address owner;
		address reverse;
		bool deleted;
		mapping (string => bytes32) data;
	}

	event Drained(uint amount);
	event FeeChanged(uint amount);
	event ReverseProposed(string name, address indexed reverse);

	mapping (bytes32 => Entry) entries;
	mapping (address => string) reverses;

	uint public fee = 1 ether;

	modifier whenUnreserved(bytes32 _name) {
		require(!entries[_name].deleted && entries[_name].owner == 0);
		_;
	}

	modifier onlyOwnerOf(bytes32 _name) {
		require(entries[_name].owner == msg.sender);
		_;
	}

	modifier whenProposed(string _name) {
		require(entries[keccak256(bytes(_name))].reverse == msg.sender);
		_;
	}

	modifier whenEntry(string _name) {
		require(
			!entries[keccak256(bytes(_name))].deleted &&
			entries[keccak256(bytes(_name))].owner != address(0)
		);
		_;
	}

	modifier whenEntryRaw(bytes32 _name) {
		require(
			!entries[_name].deleted &&
			entries[_name].owner != address(0));
		_;
	}

	modifier whenFeePaid {
		require(msg.value >= fee);
		_;
	}

	// Reservation functions
	function reserve(bytes32 _name)
		external
		payable
		whenUnreserved(_name)
		whenFeePaid
		returns (bool success)
	{
		entries[_name].owner = msg.sender;
		emit Reserved(_name, msg.sender);
		return true;
	}

	function transfer(bytes32 _name, address _to)
		external
		whenEntryRaw(_name)
		onlyOwnerOf(_name)
		returns (bool success)
	{
		entries[_name].owner = _to;
		emit Transferred(_name, msg.sender, _to);
		return true;
	}

	function drop(bytes32 _name)
		external
		whenEntryRaw(_name)
		onlyOwnerOf(_name)
		returns (bool success)
	{
		if (keccak256(bytes(reverses[entries[_name].reverse])) == _name) {
			emit ReverseRemoved(reverses[entries[_name].reverse], entries[_name].reverse);
			delete reverses[entries[_name].reverse];
		}
		entries[_name].deleted = true;
		emit Dropped(_name, msg.sender);
		return true;
	}

	// Data admin functions
	function setData(bytes32 _name, string _key, bytes32 _value)
		external
		whenEntryRaw(_name)
		onlyOwnerOf(_name)
		returns (bool success)
	{
		entries[_name].data[_key] = _value;
		emit DataChanged(_name, _key, _key);
		return true;
	}

	function setAddress(bytes32 _name, string _key, address _value)
		external
		whenEntryRaw(_name)
		onlyOwnerOf(_name)
		returns (bool success)
	{
		entries[_name].data[_key] = bytes32(_value);
		emit DataChanged(_name, _key, _key);
		return true;
	}

	function setUint(bytes32 _name, string _key, uint _value)
		external
		whenEntryRaw(_name)
		onlyOwnerOf(_name)
		returns (bool success)
	{
		entries[_name].data[_key] = bytes32(_value);
		emit DataChanged(_name, _key, _key);
		return true;
	}

	// Reverse registration functions
	function proposeReverse(string _name, address _who)
		external
		whenEntry(_name)
		onlyOwnerOf(keccak256(bytes(_name)))
		returns (bool success)
	{
		bytes32 sha3Name = keccak256(bytes(_name));
		if (entries[sha3Name].reverse != 0 && keccak256(bytes(reverses[entries[sha3Name].reverse])) == sha3Name) {
			delete reverses[entries[sha3Name].reverse];
			emit ReverseRemoved(_name, entries[sha3Name].reverse);
		}
		entries[sha3Name].reverse = _who;
		emit ReverseProposed(_name, _who);
		return true;
	}

	function confirmReverse(string _name)
		external
		whenEntry(_name)
		whenProposed(_name)
		returns (bool success)
	{
		reverses[msg.sender] = _name;
		emit ReverseConfirmed(_name, msg.sender);
		return true;
	}

	function confirmReverseAs(string _name, address _who)
		external
		whenEntry(_name)
		onlyOwner
		returns (bool success)
	{
		reverses[_who] = _name;
		emit ReverseConfirmed(_name, _who);
		return true;
	}

	function removeReverse()
		external
		whenEntry(reverses[msg.sender])
	{
		emit ReverseRemoved(reverses[msg.sender], msg.sender);
		delete entries[keccak256(bytes(reverses[msg.sender]))].reverse;
		delete reverses[msg.sender];
	}

	// Admin functions for the owner
	function setFee(uint _amount)
		external
		onlyOwner
		returns (bool)
	{
		fee = _amount;
		emit FeeChanged(_amount);
		return true;
	}

	function drain()
		external
		onlyOwner
		returns (bool)
	{
		emit Drained(address(this).balance);
		msg.sender.transfer(address(this).balance);
		return true;
	}

	// MetadataRegistry views
	function getData(bytes32 _name, string _key)
		external
		view
		whenEntryRaw(_name)
		returns (bytes32)
	{
		return entries[_name].data[_key];
	}

	function getAddress(bytes32 _name, string _key)
		external
		view
		whenEntryRaw(_name)
		returns (address)
	{
		return address(entries[_name].data[_key]);
	}

	function getUint(bytes32 _name, string _key)
		external
		view
		whenEntryRaw(_name)
		returns (uint)
	{
		return uint(entries[_name].data[_key]);
	}

	// OwnerRegistry views
	function getOwner(bytes32 _name)
		external
		view
		whenEntryRaw(_name)
		returns (address)
	{
		return entries[_name].owner;
	}

	// ReversibleRegistry views
	function hasReverse(bytes32 _name)
		external
		view
		whenEntryRaw(_name)
		returns (bool)
	{
		return entries[_name].reverse != 0;
	}

	function getReverse(bytes32 _name)
		external
		view
		whenEntryRaw(_name)
		returns (address)
	{
		return entries[_name].reverse;
	}

	function canReverse(address _data)
		external
		view
		returns (bool)
	{
		return bytes(reverses[_data]).length != 0;
	}

	function reverse(address _data)
		external
		view
		returns (string)
	{
		return reverses[_data];
	}

	function reserved(bytes32 _name)
		external
		view
		whenEntryRaw(_name)
		returns (bool)
	{
		return entries[_name].owner != 0;
	}
}
