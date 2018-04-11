var SmarcToken = artifacts.require("SmarcToken");

module.exports = function(deployer) {
  deployer.deploy(SmarcToken,0x0,0,false);
};