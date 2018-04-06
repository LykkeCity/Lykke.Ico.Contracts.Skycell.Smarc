// *.sol test doesn't work with Truffle v.4.1.5, use 4.1.4 instead:
// npm uninstall -g truffle
// npm install -g truffle@4.1.4

pragma solidity 0.4.21;

import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";
import "../contracts/SMARC.sol";

contract TestSmarc {
    function testInitialBalanceUsingDeployedContract() public {
        SMARC smarc = SMARC(DeployedAddresses.SMARC());
        Assert.equal(smarc.balanceOf(msg.sender), 0,  "No coins minted initially");
    }
}