import { expect } from "chai";
import { ethers } from "hardhat";
import { IUniswapV2Factory, IUniswapV2Router02, XtsToken} from "../typechain";
const assert = require('assert');

describe("XtsToken", function () {
  let accounts;
  let owner;
  let staker_one;
  let staker_two;
  let router;
  let factory;
  let xtsToken: XtsToken;
  let LpToken;
  let iUniswapV2Factory: IUniswapV2Factory;
  let iUniswapV2Router02: IUniswapV2Router02;

  beforeEach(async function () {

    [owner, staker_one, staker_two] = await ethers.getSigners();

    const XtsToken = await ethers.getContractFactory("XtsToken");
    xtsToken = await XtsToken.deploy();
    await xtsToken.deployed();

    router = <IUniswapV2Router02> (await ethers.getContractAt("IUniswapV2Router02", process.env.ROUTER_ADDRESS as string));
    factory = <IUniswapV2Factory> (await ethers.getContractAt("IUniswapV2Factory", process.env.FACTORY_ADDRESS as string));

    const mintTx = await xtsToken.mint(owner.address, ethers.utils.parseUnits("200000", await xtsToken._decimals()));
    await mintTx.wait();
    await xtsToken.transfer(staker_one.address, ethers.utils.parseUnits("100000", await xtsToken._decimals()));
    await xtsToken.transfer(staker_two.address, ethers.utils.parseUnits("100000", await xtsToken._decimals()));
    await xtsToken.connect(staker_one).approve(router.address, staker_one.address, ethers.constants.MaxUint256);
    await xtsToken.connect(staker_two).approve(router.address, staker_two.address, ethers.constants.MaxUint256);


    let deadline = await xtsToken.getCurrentTime();

    await router.connect(staker_one).addLiquidityETH(
      xtsToken.address,
      ethers.utils.parseUnits("100000", await xtsToken._decimals()),
      0,
      ethers.utils.parseEther("1"),
      staker_one.address,
      deadline,
        {value: ethers.utils.parseEther("1")}
    );
    });

  it("stake token", async function () {

    const Ether = await iUniswapV2Router02.WETH();
    const LpToken = await iUniswapV2Factory.getPair(xtsToken.address, Ether);

    const StakingXts = await ethers.getContractFactory("StakingXts");
    const stakingXts = await StakingXts.deploy(xtsToken.address, LpToken);
    await stakingXts.deployed();
    const startStakeTx = await stakingXts.startStake(100000);
  });
});