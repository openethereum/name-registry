//! SimpleCertifier contract, taken from paritytech/sms-verification
//! By Gav Wood (Parity Technologies), 2016.
//! Released under the Apache Licence 2.

pragma solidity ^0.4.7;

import "Owned.sol";
import "Certifier.sol";

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
