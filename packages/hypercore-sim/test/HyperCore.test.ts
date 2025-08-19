import { time, loadFixture, setCode } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre, { ethers } from "hardhat";
import { AddressLike, resolveAddress, ZeroAddress } from "ethers";
import { scale, systemAddress } from "./utils";
import { deployHyperCoreFixture } from "./deployHyperCoreFixture";

describe("HyperCore <> HyperEVM", function () {
  it("reads the L1 block number", async function () {
    const {} = await loadFixture(deployHyperCoreFixture);

    const factory = await ethers.getContractFactory("SampleReader");

    const reader = await factory.deploy();
    await reader.waitForDeployment();

    console.log(await reader.readL1BlockNumber());
  });

  describe("spot", function () {
    it("succeeds when transferring token to HyperCore", async function () {
      const { users, hyperCore, hyperCoreWrite, usdc } = await loadFixture(deployHyperCoreFixture);

      await usdc.mint(users[0], scale(10, 8));

      let spotBalance = await hyperCore.readSpotBalance(users[0], 0);
      expect(spotBalance.total).eq(0);

      await usdc.transfer(systemAddress(0), scale(5, 8));
      await hyperCoreWrite.flushActionQueue();

      spotBalance = await hyperCore.readSpotBalance(users[0], 0);
      expect(spotBalance.total).eq(scale(5, 8));
    });

    it("silently fails when transferring token to HyperCore if account hasnt been created", async function () {
      const { users, hyperCore, hyperCoreWrite, usdc } = await loadFixture(deployHyperCoreFixture);

      await usdc.mint(users[1], scale(10, 8));

      let spotBalance = await hyperCore.readSpotBalance(users[1], 0);
      expect(spotBalance.total).eq(0);

      await usdc.connect(users[1]).transfer(systemAddress(0), scale(5, 8));
      await hyperCoreWrite.flushActionQueue();

      spotBalance = await hyperCore.readSpotBalance(users[1], 0);
      expect(spotBalance.total).eq(0);
    });

    it("succeeds when transferring native gas token to HyperCore", async function () {
      const { users, hyperCore, hyperCoreWrite, usdc, KNOWN_TOKEN_HYPE } = await loadFixture(deployHyperCoreFixture);

      let spotBalance = await hyperCore.readSpotBalance(users[0], KNOWN_TOKEN_HYPE);
      expect(spotBalance.total).eq(0);

      await users[0].sendTransaction({ to: "0x2222222222222222222222222222222222222222", value: scale(1, 18) });
      await hyperCoreWrite.flushActionQueue();

      spotBalance = await hyperCore.readSpotBalance(users[0], KNOWN_TOKEN_HYPE);
      expect(spotBalance.total).eq(scale(1, 8));
    });

    it("spotSend can transfer between accounts on HyperCore", async function () {
      const { users, hyperCore, hyperCoreWrite, usdc, encodeSpotSendData } = await loadFixture(deployHyperCoreFixture);

      await usdc.mint(users[0], scale(10, 8));
      await usdc.transfer(systemAddress(0), scale(10, 8));
      await hyperCoreWrite.flushActionQueue();

      let spotBalance1 = await hyperCore.readSpotBalance(users[0], 0);
      expect(spotBalance1.total).eq(scale(10, 8));

      let spotBalance2 = await hyperCore.readSpotBalance(users[1], 0);
      expect(spotBalance2.total).eq(0);

      await users[0].sendTransaction({
        to: "0x3333333333333333333333333333333333333333",
        data: encodeSpotSendData(users[1].address, 0, scale(10, 8)),
      });
      await hyperCoreWrite.flushActionQueue();

      spotBalance1 = await hyperCore.readSpotBalance(users[0], 0);
      expect(spotBalance1.total).eq(0);

      spotBalance2 = await hyperCore.readSpotBalance(users[1], 0);
      expect(spotBalance2.total).eq(scale(10, 8));

      await users[1].sendTransaction({
        to: "0x3333333333333333333333333333333333333333",
        data: encodeSpotSendData(users[0].address, 0, scale(6, 8)),
      });
      await hyperCoreWrite.flushActionQueue();

      spotBalance1 = await hyperCore.readSpotBalance(users[0], 0);
      expect(spotBalance1.total).eq(scale(6, 8));

      spotBalance2 = await hyperCore.readSpotBalance(users[1], 0);
      expect(spotBalance2.total).eq(scale(4, 8));
    });

    it("spotSend can transfer from HyperCore to HyperEVM", async function () {
      const { users, hyperCore, hyperCoreWrite, usdc, encodeSpotSendData } = await loadFixture(deployHyperCoreFixture);

      await usdc.mint(users[0], scale(10, 8));
      await usdc.transfer(systemAddress(0), scale(10, 8));
      await hyperCoreWrite.flushActionQueue();

      expect(await usdc.balanceOf(users[0])).eq(0);

      let spotBalance1 = await hyperCore.readSpotBalance(users[0], 0);
      expect(spotBalance1.total).eq(scale(10, 8));

      await users[0].sendTransaction({
        to: "0x3333333333333333333333333333333333333333",
        data: encodeSpotSendData(systemAddress(0), 0, scale(5, 8)),
      });
      await hyperCoreWrite.flushActionQueue();

      spotBalance1 = await hyperCore.readSpotBalance(users[0], 0);
      expect(spotBalance1.total).eq(scale(5, 8));

      expect(await usdc.balanceOf(users[0])).eq(scale(5, 8));
    });

    it("spotSend can transfer forced amount from HyperCore to HyperEVM", async function () {
      const { users, hyperCore, hyperCoreWrite, usdc, encodeSpotSendData } = await loadFixture(deployHyperCoreFixture);

      await hyperCore.forceSpot(users[0], 0, scale(5, 8));
      await usdc.mint(systemAddress(0), scale(5, 8));

      let spotBalance1 = await hyperCore.readSpotBalance(users[0], 0);
      expect(spotBalance1.total).eq(scale(5, 8));

      await users[0].sendTransaction({
        to: "0x3333333333333333333333333333333333333333",
        data: encodeSpotSendData(systemAddress(0), 0, scale(5, 8)),
      });
      await hyperCoreWrite.flushActionQueue();

      spotBalance1 = await hyperCore.readSpotBalance(users[0], 0);
      expect(spotBalance1.total).eq(0);
      expect(await usdc.balanceOf(users[0])).eq(scale(5, 8));
    });

    it("spotSend can transfer native from HyperCore to HyperEVM", async function () {
      const { users, hyperCore, hyperCoreWrite, KNOWN_TOKEN_HYPE, encodeSpotSendData } = await loadFixture(
        deployHyperCoreFixture
      );

      await users[0].sendTransaction({ to: "0x2222222222222222222222222222222222222222", value: scale(10, 18) });
      await hyperCoreWrite.flushActionQueue();

      let spotBalance = await hyperCore.readSpotBalance(users[0], KNOWN_TOKEN_HYPE);
      expect(spotBalance.total).eq(scale(10, 8));

      await users[0].sendTransaction({
        to: "0x3333333333333333333333333333333333333333",
        data: encodeSpotSendData("0x2222222222222222222222222222222222222222", KNOWN_TOKEN_HYPE, scale(5, 8)),
      });
      await hyperCoreWrite.flushActionQueue();

      spotBalance = await hyperCore.readSpotBalance(users[0], KNOWN_TOKEN_HYPE);
      expect(spotBalance.total).eq(scale(5, 8));
    });
  });

  describe("perp", function () {
    it("succeeds when transferring spot to perps", async function () {
      const { users, hyperCore, hyperCoreWrite, encodeUsdClassTransfer } = await loadFixture(deployHyperCoreFixture);

      await hyperCore.forceSpot(users[0], 0, scale(10, 8));

      let spotBalance = await hyperCore.readSpotBalance(users[0], 0);
      expect(spotBalance.total).eq(scale(10, 8));
      expect(await hyperCore.readWithdrawable(users[0])).deep.eq([0n]);

      await users[0].sendTransaction({
        to: "0x3333333333333333333333333333333333333333",
        data: encodeUsdClassTransfer(scale(6, 6), true),
      });
      await hyperCoreWrite.flushActionQueue();

      spotBalance = await hyperCore.readSpotBalance(users[0], 0);
      expect(spotBalance.total).eq(scale(4, 8));
      expect(await hyperCore.readWithdrawable(users[0])).deep.eq([scale(6, 6)]);
    });

    it("silently fails when transferring more than is available from spot to perps", async function () {
      const { users, hyperCore, hyperCoreWrite, encodeUsdClassTransfer } = await loadFixture(deployHyperCoreFixture);

      await hyperCore.forceSpot(users[0], 0, scale(10, 8));

      await users[0].sendTransaction({
        to: "0x3333333333333333333333333333333333333333",
        data: encodeUsdClassTransfer(scale(20, 8), true),
      });
      await hyperCoreWrite.flushActionQueue();

      expect(await hyperCore.readWithdrawable(users[0])).deep.eq([0n]);
    });

    it("succeeds when transferring from perps to spot", async function () {
      const { users, hyperCore, hyperCoreWrite, encodeUsdClassTransfer } = await loadFixture(deployHyperCoreFixture);

      await hyperCore.forceSpot(users[0], 0, scale(10, 8));

      await users[0].sendTransaction({
        to: "0x3333333333333333333333333333333333333333",
        data: encodeUsdClassTransfer(scale(10, 6), true),
      });
      await hyperCoreWrite.flushActionQueue();

      expect(await hyperCore.readWithdrawable(users[0])).deep.eq([scale(10, 6)]);

      await users[0].sendTransaction({
        to: "0x3333333333333333333333333333333333333333",
        data: encodeUsdClassTransfer(scale(4, 6), false),
      });
      await hyperCoreWrite.flushActionQueue();

      expect(await hyperCore.readWithdrawable(users[0])).deep.eq([scale(6, 6)]);
      expect(await hyperCore.readSpotBalance(users[0], 0)).deep.eq([scale(4, 8), 0, 0]);
    });
  });

  describe("equity", function () {
    it("succeeds when transferring into vault equity", async function () {
      const { users, hyperCore, hyperCoreWrite, encodeVaultTransfer } = await loadFixture(deployHyperCoreFixture);

      await hyperCore.forcePerp(users[0], scale(10, 6));

      await users[0].sendTransaction({
        to: "0x3333333333333333333333333333333333333333",
        data: encodeVaultTransfer("0x0000000000000000000000000000000000000123", true, scale(6, 6)),
      });
      await hyperCoreWrite.flushActionQueue();

      await time.increase(60 * 4);
      await hyperCoreWrite.flushActionQueue();

      expect(await hyperCore.readWithdrawable(users[0])).deep.eq([scale(4, 6)]);

      const equity = await hyperCore.readUserVaultEquity(users[0], "0x0000000000000000000000000000000000000123");
      expect(equity.equity).eq(scale(6, 6));
    });

    it("succeeds when transferring from vault equity", async function () {
      const { users, hyperCore, hyperCoreWrite, encodeVaultTransfer } = await loadFixture(deployHyperCoreFixture);

      await hyperCore.forceVaultEquity(users[0], "0x0000000000000000000000000000000000000123", scale(10, 6), 1);

      await users[0].sendTransaction({
        to: "0x3333333333333333333333333333333333333333",
        data: encodeVaultTransfer("0x0000000000000000000000000000000000000123", false, scale(6, 6)),
      });
      await hyperCoreWrite.flushActionQueue();

      // there is a 4 second delay from a withdrawl
      expect(await hyperCore.readWithdrawable(users[0])).deep.eq([0]);

      await time.increase(4);
      await hyperCoreWrite.flushActionQueue();

      expect(await hyperCore.readWithdrawable(users[0])).deep.eq([scale(6, 6)]);

      const equity = await hyperCore.readUserVaultEquity(users[0], "0x0000000000000000000000000000000000000123");
      expect(equity.equity).eq(scale(4, 6));
    });

    it("fails silently when vault equity is locked", async function () {
      const { users, hyperCore, hyperCoreWrite, encodeVaultTransfer } = await loadFixture(deployHyperCoreFixture);

      await hyperCore.forceVaultEquity(users[0], "0x0000000000000000000000000000000000000123", scale(10, 6), 0);

      await users[0].sendTransaction({
        to: "0x3333333333333333333333333333333333333333",
        data: encodeVaultTransfer("0x0000000000000000000000000000000000000123", false, scale(6, 6)),
      });
      await hyperCoreWrite.flushActionQueue();

      expect(await hyperCore.readWithdrawable(users[0])).deep.eq([0n]);
    });
  });

  describe("staking", function () {
    it("unstaking succeeds", async function () {
      const { users, hyperCore, hyperCoreWrite, encodeStakingWithdraw } = await loadFixture(deployHyperCoreFixture);

      await hyperCore.forceStaking(users[0], 100000000n);

      await users[0].sendTransaction({
        to: "0x3333333333333333333333333333333333333333",
        data: encodeStakingWithdraw(50000000n),
      });
      await hyperCoreWrite.flushActionQueue();

      expect(await hyperCore.readDelegatorSummary(users[0])).to.deep.eq([0n, 50000000n, 50000000n, 1n]);
    });
  });
});
