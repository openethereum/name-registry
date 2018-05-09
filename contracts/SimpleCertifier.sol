//! The SimpleCertifier contract, taken from paritytech/sms-verification.
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

pragma solidity ^0.4.7;

import "./Owned.sol";
import "./Certifier.sol";

contract SimpleCertifier is Owned, Certifier {
	modifier only_delegate { if (msg.sender != delegate) return; _; }
	modifier only_certified(address _who) { if (!certs[_who].active) return; _; }

	struct Certification {
		bool active;
		mapping (string => bytes32) meta;
	}

	function certify(address _who) only_delegate {
		certs[_who].active = true;
		Confirmed(_who);
	}
	function revoke(address _who) only_delegate only_certified(_who) {
		certs[_who].active = false;
		Revoked(_who);
	}
	function certified(address _who) constant returns (bool) { return certs[_who].active; }
	function get(address _who, string _field) constant returns (bytes32) { return certs[_who].meta[_field]; }
	function getAddress(address _who, string _field) constant returns (address) { return address(certs[_who].meta[_field]); }
	function getUint(address _who, string _field) constant returns (uint) { return uint(certs[_who].meta[_field]); }
	function setDelegate(address _new) only_owner { delegate = _new; }

	mapping (address => Certification) certs;
	// So that the server posting puzzles doesn't have access to the ETH.
	address public delegate = msg.sender;
}
