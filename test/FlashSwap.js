const { ethers } = require('hardhat');
const { expect } = require('chai');

describe('Flash swap test', function () {
    it('An attempt of cyclic flash loan has been made', async function () {
        let usdc = await ethers.getContractAt('IERC20', '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48');
        let [owner,] = await ethers.getSigners();

        let flashLoanFactory = await ethers.getContractFactory('FlashLoan');
        let flashLoan = await flashLoanFactory.deploy();
        await flashLoan.deployed();

        await usdc.transfer(flashLoan.address, 1, { from: owner.address });

        /**
         * Since it will not be possible to earn money on a cyclical
         * flash loan, the swap must be rejected.
         */
        await expect(flashLoan.run(usdc.address, 1, { from: owner.address }))
            .to.be.revertedWith("ERC20: transfer amount exceeds balance");
    });
});
