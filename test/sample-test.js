import { MockProvider } from 'ethereum-waffle';
const { expect } = require("chai");
const { ethers } = require("hardhat");


describe("Greeter", function () {
    it("Should return the new greeting once it's changed", async function () {

      const [wallet, otherWallet] = new MockProvider().getWallets();
      
      const Greeter = await ethers.getContractFactory("AaveMiddleContract");
      const greeter = await Greeter.deploy();
      await greeter.deployed();
      
      greeter.depositERC20();
      expect(await greeter.greet()).to.equal("Hello, world!");
  
      const setGreetingTx = await greeter.setGreeting("Hola, mundo!");
  
      // wait until the transaction is mined
      await setGreetingTx.wait();
  
      expect(await greeter.greet()).to.equal("Hola, mundo!");
    });
  });