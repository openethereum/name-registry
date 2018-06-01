//! The SimpleCertifier contract, used by service transaction.
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
	modifier onlyDelegate {
		require(msg.sender == delegate);
		_;
	}

	modifier onlyCertified(address _who) {
		require(certs[_who].active);
		_;
	}

	struct Certification {
		bool active;
	}

	function certify(address _who) onlyDelegate public {
		certs[_who].active = true;
		emit Confirmed(_who);
	}

	function revoke(address _who) onlyDelegate onlyCertified(_who) public {
		certs[_who].active = false;
		emit Revoked(_who);
	}

	function certified(address _who) view public returns (bool) {
		return certs[_who].active;
	}

	function setDelegate(address _new) onlyOwner public {
		delegate = _new;
	}

	mapping (address => Certification) certs;
	// So that the server posting puzzles doesn't have access to the ETH.
	address public delegate = msg.sender;
}
