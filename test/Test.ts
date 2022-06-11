import { expect } from "chai";
import { ethers } from "hardhat";
import { IUniswapV2Factory, IUniswapV2Router02, XtsToken} from "../typechain";
import assert from 'assert';
import {providers} from "ethers";

describe("XtsToken", function () {
  let accounts;
  let owner;
  let staker_one;
  let staker_two;
  let router: IUniswapV2Router02;
  let factory: IUniswapV2Factory;
  let xtsToken: XtsToken;
  let LpToken;

  
  it("stake token", async function () {
    let provider = ethers.getDefaultProvider('homestead');
    let time = await (await provider.getBlock('latest')).timestamp;
    [owner, staker_one, staker_two] = await ethers.getSigners();

    const XtsToken = await ethers.getContractFactory("XtsToken");
    xtsToken = await XtsToken.deploy();
    await xtsToken.deployed();

   const router = await ethers.getContractAt("IUniswapV2Router02", process.env.ROUTER_ADDRESS as string);
   const factory = await ethers.getContractAt("IUniswapV2Factory", process.env.FACTORY_ADDRESS as string);

    const mintTx = await xtsToken.mint(owner.address, ethers.utils.parseUnits("200000", await xtsToken._decimals()));
    await mintTx.wait();
    const mint1Tx = await xtsToken.mint(staker_one.address, ethers.utils.parseUnits("200000", await xtsToken._decimals()));
    await mint1Tx.wait();
    const mint2Tx = await xtsToken.mint(staker_two.address, ethers.utils.parseUnits("200000", await xtsToken._decimals()));
    await mint2Tx.wait();
    await xtsToken.transfer(staker_one.address, ethers.utils.parseUnits("100000", await xtsToken._decimals()));
    await xtsToken.transfer(staker_two.address, ethers.utils.parseUnits("100000", await xtsToken._decimals()));
    await xtsToken.connect(staker_one).approve(router.address, staker_one.address, ethers.constants.MaxUint256);
    await xtsToken.connect(staker_two).approve(router.address, staker_two.address, ethers.constants.MaxUint256);
    await xtsToken.connect(owner).approve(router.address, owner.address, ethers.constants.MaxUint256);
    await xtsToken.approve(owner.address, staker_one.address, 100000);
    await xtsToken.approve(owner.address, staker_two.address, 100000);


    let deadline = time + 100;

    await router.connect(owner).addLiquidityETH(
      xtsToken.address,
      ethers.utils.parseUnits("100000", await xtsToken._decimals()),
      0,
      ethers.utils.parseEther("1"),
      staker_one.address,
      deadline,
        {value: ethers.utils.parseEther("1")}
    );


    const Ether = await router.WETH();
    const LpToken = await factory.getPair(xtsToken.address, Ether);

    const StakingXts = await ethers.getContractFactory("StakingXts");
    const stakingXts = await StakingXts.deploy(xtsToken.address, LpToken);
    await stakingXts.deployed();
    const startStakeTx = await stakingXts.startStake(1);
    await startStakeTx.wait();
  });
});
