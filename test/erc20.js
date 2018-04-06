var SMARC = artifacts.require('./SMARC.sol')

contract('SMARC', (accounts) => {
    // redeploy token contract before each test
    var contract;

    beforeEach(() => {
        return SMARC.new().then(instance => contract = instance);
    });

    describe("ERC20 Basic Functionality", () => {
        it('creation: should create an initial balance of 0 for everyone', () => {
            contract.balanceOf(accounts[0])
                .then(res => assert.strictEqual(res.toNumber(), 0))
                .catch(e => new Error(err));
        });
    });
})
