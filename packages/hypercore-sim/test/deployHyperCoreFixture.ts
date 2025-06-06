import hre, { ethers } from "hardhat";
import { AbiCoder, AddressLike, BigNumberish, getBytes, resolveAddress, ZeroAddress } from "ethers";
import { CoreWriter__factory, SpotERC20__factory } from "../scripts/typechain-types";
import { deployHyperCoreSim } from "../scripts";

const ABI = AbiCoder.defaultAbiCoder();

export const deployHyperCoreFixture = async () => {
  const [signer, user2, user3] = await ethers.getSigners();

  const { hyperCore, hyperCoreWrite, hyperCoreSystem } = await deployHyperCoreSim();

  await hyperCore.registerTokenInfo(0, {
    name: "USDC",
    spots: [],
    deployerTradingFeeShare: 0,
    deployer: ZeroAddress,
    evmContract: ZeroAddress,
    szDecimals: 8,
    weiDecimals: 8,
    evmExtraWeiDecimals: 0,
  });
  await hyperCore.deploySpotERC20(0);

  const usdc = await hyperCore.readTokenInfo(0);

  await hyperCore.forceAccountCreation(signer);

  const encodeAction = (kind: number, data: string) => {
    return new Uint8Array([1, 0, 0, kind, ...getBytes(data)]);
  };

  const encodeSpotSendData = (destination: string, token: BigNumberish, wei: BigNumberish) => {
    const action = encodeAction(6, ABI.encode(["address", "uint64", "uint64"], [destination, token, wei]));
    return CoreWriter__factory.createInterface().encodeFunctionData("sendRawAction", [action]);
  };

  const encodeUsdClassTransfer = (ntl: BigNumberish, toPerp: boolean) => {
    const action = encodeAction(7, ABI.encode(["uint64", "bool"], [ntl, toPerp]));
    return CoreWriter__factory.createInterface().encodeFunctionData("sendRawAction", [action]);
  };

  const encodeVaultTransfer = (vault: string, isDeposit: boolean, usd: BigNumberish) => {
    const action = encodeAction(2, ABI.encode(["address", "bool", "uint64"], [vault, isDeposit, usd]));
    return CoreWriter__factory.createInterface().encodeFunctionData("sendRawAction", [action]);
  };

  return {
    users: [signer, user2, user3],
    hyperCore,
    hyperCoreWrite,
    hyperCoreSystem,
    usdc: SpotERC20__factory.connect(usdc.evmContract, signer),
    KNOWN_TOKEN_HYPE: 150,
    encodeSpotSendData,
    encodeUsdClassTransfer,
    encodeVaultTransfer,
  };
};
