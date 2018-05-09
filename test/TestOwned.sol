pragma solidity ^0.4.21;

import "truffle/Assert.sol";
import "../contracts/Owned.sol";


contract TestOwned {
	function testSetOwner() public {
		Owned owned = new Owned();

		owned.setOwner(0x0000000000000000000000000000000000000001);

		address expected = 0x0000000000000000000000000000000000000001;
		Assert.equal(address(owned.owner()), address(expected), "Owner should be 0x1");
	}
}
