//based on https://github.com/ConsenSys/Tokens/tree/master/test

var SmarcToken = artifacts.require('./contracts/SmarcToken.sol')


contract('SmarcToken', function (accounts) {

    //https://ethereum.stackexchange.com/questions/15567/truffle-smart-contract-testing-does-not-reset-state/15574#15574
    var contract;
    beforeEach(function () {
        return SmarcToken.new(0x0,0,false)
            .then(function(instance) {
                contract = instance;
            });
    });

    const evmThrewRevertError = (err) => {
        if (err.toString().includes('Error: VM Exception while processing transaction: revert')) {
            return true
        }
        return false
    }

    //************************** TEST ERC20 - the smart contract code is copy&paste from reliable sources ************
    it("test ERC20 basic functionality", function () {
        return SmarcToken.deployed().then(function (instance) {
            return contract.balanceOf.call(accounts[0], {from: accounts[0]});
        }).then(function (balance) {
            assert.equal(balance.valueOf(), 0, "everything should be empty");
            return contract.generateTokens(accounts[0], 1000, {from: accounts[1]});
        }).then(function (retVal) {
            assert.equal(false, "only owner can mint");
        }).catch(function (e) {
            return contract.generateTokens(accounts[0], 1000, {from: accounts[0]});
        }).then(function (retVal) {
            return contract.balanceOf.call(accounts[0], {from: accounts[0]});
        }).then(function (balance) {
            assert.equal(balance.valueOf(), 1000, "balance is 1000, seen by any account");
            return contract.balanceOf.call(accounts[0], {from: accounts[1]});
        }).then(function (balance) {
            assert.equal(balance.valueOf(), 1000, "balance is 1000, seen by any account");
            return contract.totalSupply.call({from: accounts[1]});
        }).then(function (totalSupply) {
            assert.equal(totalSupply.valueOf(), 1000, "unlocked tokens are 1000");
            return contract.totalSupply.call({from: accounts[1]});
        }).then(function (totSupply) {
            assert.equal(totSupply.valueOf(), 9900000 + 1000, "unlocked tokens are 1000");
            return contract.transfer(accounts[1], 1, {from: accounts[0]});
        }).then(function (retVal) {
            assert.equal(false, "minting not done yet, cannot transfor");
        }).catch(function (e) {
            //minting done
            return contract.enableTransfers(true,{from: accounts[0]});
        }).then(function (retVal) {
            return contract.transfer(accounts[1], 1, {from: accounts[0]});
        }).then(function (retVal) {
            assert.equal(false, "account 1 does not have any tokens");
        }).catch(function (e) {
            return contract.transfer(accounts[1], 0, {from: accounts[1]});
        }).then(function (retVal) {
            assert.equal(false, "cannot transfor 0 tokens");
        }).catch(function (e) {
            return contract.transfer(accounts[1], -1, {from: accounts[1]});
        }).then(function (retVal) {
            assert.equal(false, "negative values are not possible");
        }).catch(function (e) {
            return contract.transfer(accounts[0], 1, {from: accounts[1]});
        }).then(function (retVal) {
            assert.equal(false, "cannot steal tokens from another account");
        }).catch(function (e) {
            return contract.transfer(accounts[0], 1001, {from: accounts[1]});
        }).then(function (retVal) {
            assert.equal(false, "account 0 only has 1000 tokens, cannot transfor 1001");
        }).catch(function (e) {
            return contract.transfer(accounts[0], 1000, {from: accounts[0]});
        }).then(function (retVal) {
            //transfer was successful
            return contract.balanceOf.call(accounts[0], {from: accounts[0]});
        }).then(function (balance) {
            assert.equal(balance.valueOf(), 1000, "we sent from account 0 to account 0, so account 0 has still 1000 tokens");
            return contract.transfer(accounts[1], 1000, {from: accounts[0]});
        }).then(function (retVal) {
            return contract.balanceOf.call(accounts[0], {from: accounts[1]});
        }).then(function (balance) {
            assert.equal(balance.valueOf(), 0, "we transfer all tokens to account 1");
            return contract.balanceOf.call(accounts[1], {from: accounts[2]});
        }).then(function (balance) {
            assert.equal(balance.valueOf(), 1000, "account 1 has 1000 tokens ");
        });
    });


// CREATION

    it('creation: should create an initial balance of 0 for everyone', function () {
        SmarcToken.new(0x0,0,false,{from: accounts[0]}).then(function (owner) {
            return owner.balanceOf.call(accounts[0])
        }).then(function (result) {
            assert.strictEqual(result.toNumber(), 0)
        }).catch((err) => { throw new Error(err) })
    })


    // Locking

    it('locking: should not allow locked addresses to do transfers', function () {
        SmarcToken.new(0x0,0,false,{from: accounts[0]}).then(function (owner) {
            return contract.setLocks([accounts[0]],[1556582400],{from: accounts[0]})
        }).then(function (result){
        	return contract.generateTokens(accounts[0], 10000, {from: accounts[0]});
        }).then(function (result) {
                return contract.transfer(accounts[1], 1000, {from: accounts[0]})
        }).then(function (retVal) {
            return contract.balanceOf.call(accounts[0], {from: accounts[1]});
        }).then(function (balance) {
            assert.equal(balance.valueOf(), 10000, "no tokens where transfered");
        }).then(function (result) {
            return contract.approve(accounts[1], 100, {from: accounts[0]})
        }).then(function (result) {
            return contract.allowance.call(accounts[0], accounts[1])
        }).then(function (result) {
            assert.strictEqual(result.toNumber(), 100)
            return contract.transferFrom(accounts[0], accounts[2], 100, {from: accounts[1]})
        }).then(function (retVal) {
            return contract.balanceOf.call(accounts[0], {from: accounts[1]});
        }).then(function (balance) {
            assert.equal(balance.valueOf(), 10000, "no tokens where transfered");
        });
    })


})