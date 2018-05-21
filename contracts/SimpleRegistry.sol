//! The simple registry contract.
//!
//! Copyright 2016 Gavin Wood, Parity Technologies Ltd.
//!
//! Licensed under the Apache License, Version 2.0 (the "License");
//! you may not use this file except in compliance with the License.
//! You may obtain a copy of the License at
//!
//!     http://www.apache.org/licenses/LICENSE-2.0
//!
//! Unless required by applicable law or agreed to in writing, software
//! distributed under the License is distributed on an "AS IS" BASIS,
//! WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//! See the License for the specific language governing permissions and
//! limitations under the License.

pragma solidity ^0.4.0;

import "./Owned.sol";


contract MetadataRegistry {
	event DataChanged(bytes32 indexed name, string key, string plainKey);

	function getData(bytes32 _name, string _key) view public returns (bytes32);
	function getAddress(bytes32 _name, string _key) view public returns (address);
	function getUint(bytes32 _name, string _key) view public returns (uint);
}


contract OwnerRegistry {
	event Reserved(bytes32 indexed name, address indexed owner);
	event Transferred(bytes32 indexed name, address indexed oldOwner, address indexed newOwner);
	event Dropped(bytes32 indexed name, address indexed owner);

	function getOwner(bytes32 _name) view public returns (address);
}


contract ReverseRegistry {
	event ReverseConfirmed(string indexed name, address indexed reverse);
	event ReverseRemoved(string indexed name, address indexed reverse);

	function hasReverse(bytes32 _name) view public returns (bool);
	function getReverse(bytes32 _name) view public returns (address);
	function canReverse(address _data) view public returns (bool);
	function reverse(address _data) view public returns (string);
}


contract SimpleRegistry is Owned, MetadataRegistry, OwnerRegistry, ReverseRegistry {
	struct Entry {
		address owner;
		address reverse;
		bool deleted;
		mapping (string => bytes32) data;
	}

	event Drained(uint amount);
	event FeeChanged(uint amount);
	event ReverseProposed(string indexed name, address indexed reverse);

	// Registry functions.
	function getData(bytes32 _name, string _key) whenEntryRaw(_name) view public returns (bytes32) {
		return entries[_name].data[_key];
	}

	function getAddress(bytes32 _name, string _key) whenEntryRaw(_name) view public returns (address) {
		return address(entries[_name].data[_key]);
	}

	function getUint(bytes32 _name, string _key) whenEntryRaw(_name) view public returns (uint) {
		return uint(entries[_name].data[_key]);
	}

	// OwnerRegistry function.
	function getOwner(bytes32 _name) whenEntryRaw(_name) view public returns (address) {
		return entries[_name].owner;
	}

	// ReversibleRegistry functions.
	function hasReverse(bytes32 _name) whenEntryRaw(_name) view public returns (bool) {
		return entries[_name].reverse != 0;
	}

	function getReverse(bytes32 _name) whenEntryRaw(_name) view public returns (address) {
		return entries[_name].reverse;
	}

	function canReverse(address _data) view public returns (bool) {
		return bytes(reverses[_data]).length != 0;
	}

	function reverse(address _data) view public returns (string) {
		return reverses[_data];
	}

	// Reservation functions.
	function reserve(bytes32 _name) whenEntryRaw(_name) whenUnreserved(_name) whenFeePaid payable public returns (bool success) {
		entries[_name].owner = msg.sender;
		emit Reserved(_name, msg.sender);
		return true;
	}

	function reserved(bytes32 _name) whenEntryRaw(_name) view public returns (bool) {
		return entries[_name].owner != 0;
	}

	function transfer(bytes32 _name, address _to) whenEntryRaw(_name) onlyOwnerOf(_name) public returns (bool success) {
		entries[_name].owner = _to;
		emit Transferred(_name, msg.sender, _to);
		return true;
	}

	function drop(bytes32 _name) whenEntryRaw(_name) onlyOwnerOf(_name) public returns (bool success) {
		delete reverses[entries[_name].reverse];
		entries[_name].deleted = true;
		emit Dropped(_name, msg.sender);
		return true;
	}

	// Data admin functions.
	function setData(bytes32 _name, string _key, bytes32 _value) whenEntryRaw(_name) onlyOwnerOf(_name) public returns (bool success) {
		entries[_name].data[_key] = _value;
		emit DataChanged(_name, _key, _key);
		return true;
	}

	function setAddress(bytes32 _name, string _key, address _value) whenEntryRaw(_name) onlyOwnerOf(_name) public returns (bool success) {
		entries[_name].data[_key] = bytes32(_value);
		emit DataChanged(_name, _key, _key);
		return true;
	}

	function setUint(bytes32 _name, string _key, uint _value) whenEntryRaw(_name) onlyOwnerOf(_name) public returns (bool success) {
		entries[_name].data[_key] = bytes32(_value);
		emit DataChanged(_name, _key, _key);
		return true;
	}

	// Reverse registration.
	function proposeReverse(string _name, address _who) whenEntry(_name) onlyOwnerOf(keccak256(_name)) public returns (bool success) {
		bytes32 sha3Name = keccak256(_name);
		if (entries[sha3Name].reverse != 0 && keccak256(reverses[entries[sha3Name].reverse]) == sha3Name) {
			delete reverses[entries[sha3Name].reverse];
			emit ReverseRemoved(_name, entries[sha3Name].reverse);
		}
		entries[sha3Name].reverse = _who;
		emit ReverseProposed(_name, _who);
		return true;
	}

	function confirmReverse(string _name) whenEntry(_name) whenProposed(_name) public returns (bool success) {
		reverses[msg.sender] = _name;
		emit ReverseConfirmed(_name, msg.sender);
		return true;
	}

	function confirmReverseAs(string _name, address _who) whenEntry(_name) onlyOwner public returns (bool success) {
		reverses[_who] = _name;
		emit ReverseConfirmed(_name, _who);
		return true;
	}

	function removeReverse() whenEntry(reverses[msg.sender]) public {
		emit ReverseRemoved(reverses[msg.sender], msg.sender);
		delete entries[keccak256(reverses[msg.sender])].reverse;
		delete reverses[msg.sender];
	}

	// Admin functions for the owner.
	function setFee(uint _amount) onlyOwner public returns (bool) {
		fee = _amount;
		emit FeeChanged(_amount);
		return true;
	}

	function drain() onlyOwner public returns (bool) {
		emit Drained(address(this).balance);
		msg.sender.transfer(address(this).balance);
		return true;
	}

	modifier whenUnreserved(bytes32 _name) {
		require(entries[_name].owner == 0);
		_;
	}

	modifier onlyOwnerOf(bytes32 _name) {
		require(entries[_name].owner == msg.sender);
		_;
	}

	modifier whenProposed(string _name) {
		require(entries[keccak256(_name)].reverse == msg.sender);
		_;
	}

	modifier whenEntry(string _name) {
		require(!entries[keccak256(_name)].deleted);
		_;
	}

	modifier whenEntryRaw(bytes32 _name) {
		require(!entries[_name].deleted);
		_;
	}

	modifier whenFeePaid {
		require(msg.value >= fee);
		_;
	}

	mapping (bytes32 => Entry) entries;
	mapping (address => string) reverses;

	uint public fee = 1 ether;
}
