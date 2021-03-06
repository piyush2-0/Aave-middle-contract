const { expect } = require("chai");
const { ethers } = require("hardhat");
const { parseEther, parseUnits } = require("ethers/lib/utils");
const aDaiAbi = require("./aDaiAbi.js");

describe("Aave Middle Contract Test", function () {
  let owner;

  const daiAddress = "0x6b175474e89094c44da98b954eedeac495271d0f";
  const aDaiAddress = "0x028171bCA77440897B824Ca71D1c56caC55b68A3";

  beforeEach(async () => {
    const middleContractFactory = await ethers.getContractFactory(
      "AaveMiddleContract"
    );
    const proxyContractFactory = await ethers.getContractFactory(
      "Proxy"
    );
    //console.log(proxyContractFactory);
    [owner] = await ethers.getSigners();
    middleContract = await middleContractFactory.deploy();
    proxy = await proxyContractFactory.deploy();
    await proxy.upgrade(middleContract.address);
    proxyInstance = await ethers.getContractAt("AaveMiddleContract", proxy.address);
    proxyInstance.initialize();
  });

  describe("Deploy the contract", async () => {
    it("Should set the right owner", async () => {
      expect(await proxyInstance.getOwner()).to.eq(owner.address);
    });
  });

  describe("Deposit ERC20", async () => {
    let Dai, aDai;
    beforeEach(async () => {
      const tokenArtifact = await artifacts.readArtifact("IERC20Upgradeable");
      Dai = new ethers.Contract(daiAddress, tokenArtifact.abi, ethers.provider);
      await Dai.connect(owner).approve(
        proxyInstance.address,
        parseUnits("0.000001", 18)
      );

      aDai = new ethers.Contract(aDaiAddress, aDaiAbi, ethers.provider);
    });

    it("Deposit ERC20 tokens to Aave through contract", async () => {
      await expect(() =>
      proxyInstance.depositERC20(daiAddress, parseUnits("100", 0), 0)
      ).to.changeTokenBalances(
        Dai,
        [owner, aDai],
        [parseUnits("-100", 0), parseUnits("100", 0)]
      );
    });
  });

  describe("Withdraw ERC20", async () => {
    let Dai, aDai;
    beforeEach(async () => {
      const tokenArtifact = await artifacts.readArtifact("IERC20Upgradeable");
      Dai = new ethers.Contract(daiAddress, tokenArtifact.abi, ethers.provider);
      await Dai.connect(owner).approve(
        proxyInstance.address,
        parseUnits("1", 18)
      );
      aDai = new ethers.Contract(aDaiAddress, aDaiAbi, ethers.provider);

      await  proxyInstance.depositERC20(daiAddress, parseUnits("100", 0), 0);
    });

    it("Should fail on attempting to withdraw more than balance", async () => {
      await expect(
        proxyInstance.withdrawERC20(daiAddress, 1000, aDaiAddress)
      ).to.be.revertedWith("NOT ENOUGH aTOKENS");
    });

    it("Token balance should update on withdraw", async () => {
      await expect(() =>
      proxyInstance.withdrawERC20(daiAddress, 100, aDaiAddress)
      ).to.changeTokenBalances(
        Dai,
        [owner, aDai],
        [parseUnits("100", 0), parseUnits("-100", 0)]
      ); // increased amount to account for interest
    });
  });

  describe("Borrow ERC20", async () => {
    let Dai, aDai;
    beforeEach(async () => {
      const tokenArtifact = await artifacts.readArtifact("IERC20Upgradeable");
      Dai = new ethers.Contract(daiAddress, tokenArtifact.abi, ethers.provider);
      await Dai.connect(owner).approve(
        proxyInstance.address,
        parseUnits("1", 18)
      );
      aDai = new ethers.Contract(aDaiAddress, aDaiAbi, ethers.provider);
    });

    it("Should fail if borrow is attempted without depositing ETH", async () => {
      await expect(
        proxyInstance.borrowERC20(daiAddress, parseUnits("100", 0), 1, 0)
      ).to.be.revertedWith("DEPOSIT ETHER FIRST");
    });

    it("Should fail on trying to borrow more amount in tokens than liquidity", async () => {
      await  proxyInstance.depositEth(0, {
        value: parseEther("1"),
      });

      await expect(
        proxyInstance.borrowERC20(daiAddress, parseUnits("10000", 0), 1, 0)
      ).to.be.revertedWith("BORROW FAILED: NOT ENOUGH COLLATERAL");
    });

    it("Should borrow ERC20 tokens", async () => {
      await expect(() =>
      proxyInstance.depositEth(0, {
          value: parseEther("1"),
        })
      ).to.changeEtherBalances([owner], [parseEther("-1")]);

      await expect(() =>
      proxyInstance.borrowERC20(daiAddress, parseUnits("100", 0), 1, 0)
      ).to.changeTokenBalances(
        Dai,
        [owner, aDai],
        [parseUnits("100", 0), parseUnits("-100", 0)]
      );
    });
  });

  describe("Repay ERC20", async () => {
    let Dai, aDai;
    beforeEach(async () => {
      const tokenArtifact = await artifacts.readArtifact("IERC20Upgradeable");
      Dai = new ethers.Contract(daiAddress, tokenArtifact.abi, ethers.provider);
      await Dai.connect(owner).approve(
        proxyInstance.address,
        parseUnits("1", 18)
      );
      aDai = new ethers.Contract(aDaiAddress, aDaiAbi, ethers.provider);

      await  proxyInstance.depositEth(0, {
        value: parseEther("1"),
      });

      await  proxyInstance.borrowERC20(daiAddress, parseUnits("100", 0), 1, 0);
    });

    it("Should fail on trying to repay more than borrowed", async () => {
      await expect(
        proxyInstance.repayERC20(daiAddress, parseUnits("110", 0), 1)
      ).to.be.revertedWith("REPAY AMOUNT MORE THAN BORROWED AMOUNT");
    });

    it("Should repay tokens and update borrowBalance", async () => {
      await expect(() =>
      proxyInstance.repayERC20(daiAddress, parseUnits("100", 0), 1)
      ).to.changeTokenBalances(
        Dai,
        [owner, aDai],
        [parseUnits("-100", 0), parseUnits("100", 0)]
      );
    });
    //});
  });

  describe("Deposit Ether", async () => {
    it("Should deposit ether in Aave through contract", async () => {
      await expect(
        await  proxyInstance.depositEth(0, {
          value: parseEther("1"),
        })
      ).to.changeEtherBalances([owner], [parseEther("-1")]);

      await expect(
        await  proxyInstance.depositEth(0, {
          value: parseEther("2"),
        })
      ).to.changeEtherBalances([owner], [parseEther("-2")]);
    });
  });

  describe("Withdraw Ether", async () => {
    beforeEach(async () => {
      await expect(
        await  proxyInstance.depositEth(0, {
          value: parseEther("0.000000000000000003"),
        })
      );
    });
    describe("Success", async () => {
      it("Should withdraw ether from Aave and send it to user", async () => {
        await expect(
          await  proxyInstance.withdrawEth(2)
        ).to.changeEtherBalances([owner], [parseEther("0.000000000000000002")]);
      });
    });

    describe("Failure", async () => {
      it("Should not execute withdraws greater than balance", async () => {
        await expect(
          proxyInstance.withdrawEth(5000000000000000)
        ).to.be.revertedWith("NOT ENOUGH aTOKENS");
      });
    });
  });

  describe("Borrow Ether", async () => {
    let Dai, aDai;
    beforeEach(async () => {
      const tokenArtifact = await artifacts.readArtifact("IERC20Upgradeable");
      Dai = new ethers.Contract(daiAddress, tokenArtifact.abi, ethers.provider);
      await Dai.connect(owner).approve(
        proxyInstance.address,
        parseUnits("100", 18)
      );

      aDai = new ethers.Contract(aDaiAddress, aDaiAbi, ethers.provider);
    });

    it("Should fail when borrow is attempted without depositting tokens", async () => {
      await expect(
        proxyInstance.borrowEth(
          parseEther("0.0000000001"),
          1,
          0,
          aDaiAddress,
          daiAddress
        )
      ).to.be.revertedWith("DEPOSIT TOKENS FIRST");
    });

    it("Should fail on attempting to borrow more than liquidity", async () => {
      await expect(() =>
      proxyInstance.depositERC20(daiAddress, parseUnits("0.000001", 18), 0)
      ).to.changeTokenBalance(Dai, aDai, parseUnits("0.000001", 18));

      await expect(
        proxyInstance.borrowEth(
          parseEther("1000"),
          1,
          0,
          aDaiAddress,
          daiAddress
        )
      ).to.be.revertedWith("BORROW FAILED: NOT ENOUGH COLLATERAL");
    });

    it("Should borrow ETH", async () => {
      await expect(() =>
      proxyInstance.depositERC20(daiAddress, 100000000, 0)
      ).to.changeTokenBalance(Dai, aDai, 100000000);

      await expect(
        await  proxyInstance.borrowEth(1, 1, 0, aDaiAddress, daiAddress)
      ).to.changeEtherBalances([owner], [parseEther("0.000000000000000001")]);
    });
  });

  describe("Repay Ether", async () => {
    let Dai, aDai;
    beforeEach(async () => {
      const tokenArtifact = await artifacts.readArtifact("IERC20Upgradeable");
      Dai = new ethers.Contract(daiAddress, tokenArtifact.abi, ethers.provider);
      await Dai.connect(owner).approve(
        proxyInstance.address,
        parseUnits("1", 18)
      );
      aDai = new ethers.Contract(aDaiAddress, aDaiAbi, ethers.provider);

      await  proxyInstance.depositERC20(daiAddress, 100000000, 0);

      await  proxyInstance.borrowEth(1, 1, 0, aDaiAddress, daiAddress);
    });

    it("Should fail on attempting to repay more than borrowed amount", async () => {
      await expect(
        proxyInstance.repayEth(1, {
          value: parseEther("100"),
        })
      ).to.be.revertedWith("REPAY AMOUNT MORE THAN BORROWED AMOUNT");
    });

    it("Should repay debt and update borrowBalanceCurrent", async () => {
      await  proxyInstance.repayEth(1, {
        value: 1,
      });

      await expect(await  proxyInstance.getEthBorrowBalance()).to.eq(0);
    });
  });
});
