// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "hardhat/console.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Callee.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * A smart contract implementing a cyclic flash loan along the following way:
 * wETH -> LINK -> DAI -> wETH
 *
 * @author Igor Podtsepko (i.podtsepko2002@gmail.com)
 */
contract FlashLoan is IUniswapV2Callee {
    address private constant wETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant LINK = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address private constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    uint private borrowed;

    /**
     * A function that receives wETH tokens and performs a cyclic flash loan
     * along the following way: wETH -> LINK -> DAI -> wETH.
     *
     * @param borrow address of tokens to be exchanged for wETH tokens
     * @param amount number of tokens to exchange for wETH tokens
     */
    function run(address borrow, uint amount) external {
        address pairAddress;
        IUniswapV2Pair pair;

        (pairAddress, pair) = _getUniswapPair(borrow, wETH);

        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair)
            .getReserves();
        if (pair.token0() == borrow) {
            borrowed =
                (997 * amount * uint(reserve1)) /
                (1000 * uint(reserve0) + 997 * amount);
        } else {
            borrowed =
                (997 * amount * uint(reserve0)) /
                (1000 * uint(reserve1) + 997 * amount);
        }
        borrowed += 1; // We borrow more than the balance allows.
        // Now let's try to earn at the expense of this loan

        console.log("    Borrowed tokens swapped on %d wETH", borrowed);

        uint amount0 = pair.token0() != borrow ? borrowed : 0;
        uint amount1 = pair.token1() != borrow ? borrowed : 0;

        pair.swap(amount0, amount1, address(this), abi.encode(borrow));
    }

    /**
     * The function that is called after the token transfer during
     * the swap within the uniswap pair.
     */
    function uniswapV2Call(
        address sender,
        uint amount0,
        uint amount1,
        bytes calldata data
    ) external override {
        console.log("    flashLoan.uniswapV2Call");
        require(
            amount0 == 0 || amount1 == 0,
            "Both amounts are not equal to zero"
        );

        uint wEthAmount = amount0 + amount1;
        require(wEthAmount > 0, "Both amounts equals to zero"); // at least one of the provided amounts is not equal to zero

        IUniswapV2Pair caller = IUniswapV2Pair(msg.sender);

        address token0 = caller.token0();
        address token1 = caller.token1();

        address pairAddress;
        IUniswapV2Pair pair;

        (pairAddress, pair) = _getUniswapPair(token0, token1);

        require(
            address(this) == sender,
            "Called invalid callback: the specified sender address "
            "is not equal to address of this contract"
        );

        require(
            pairAddress == msg.sender,
            "Called invalid callback: the calling party does not match the expected"
        );

        uint linkAmount = _swap(wETH, LINK, wEthAmount);
        console.log(
            "        \u2713 Swap maked: %d wETH -> %d LINK",
            wEthAmount,
            linkAmount
        );

        uint daiAmount = _swap(LINK, DAI, linkAmount);
        console.log(
            "        \u2713 Swap maked: %d LINK -> %d DAI",
            linkAmount,
            daiAmount
        );

        wEthAmount = _swap(DAI, wETH, daiAmount);
        console.log(
            "        \u2713 Swap maked: %d DAI -> %d wETH",
            daiAmount,
            wEthAmount
        );

        console.log();
        console.log(
            "        After a cyclic flash loan, %d wETH remained",
            wEthAmount
        );
        console.log("        Losses: %d wETH", borrowed - wEthAmount);

        address borrow = abi.decode(data, (address));
        IERC20(borrow).transfer(pairAddress, wEthAmount);
    }

    /**
     * This function performs a swap using a uniswap pair for the provided addresses.
     * The exchange is carried out as profitably as possible.
     *
     * @param token0 the address of the tokens exchanged
     * @param token1 the address of the token to be exchanged for
     * @param amountIn the number of tokens numbered zero for exchange.
     *
     * @return amountOut the number of tokens received is number one
     */
    function _swap(
        address token0,
        address token1,
        uint amountIn
    ) internal returns (uint amountOut) {
        (address pairAddress, IUniswapV2Pair pair) = _getUniswapPair(
            token0,
            token1
        );

        address _token0 = pair.token0();
        address _token1 = pair.token1();

        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pair)
            .getReserves();

        if (token0 == _token0) {
            amountOut =
                (997 * amountIn * uint(reserve1)) /
                (1000 * uint(reserve0) + 997 * amountIn);
        } else {
            amountOut =
                (997 * amountIn * uint(reserve0)) /
                (1000 * uint(reserve1) + 997 * amountIn);
        }

        uint _amount0 = _token0 != token0 ? amountOut : 0;
        uint _amount1 = _token1 != token0 ? amountOut : 0;

        IERC20(token0).transfer(pairAddress, amountIn);
        pair.swap(_amount0, _amount1, address(this), "");
    }

    /**
     * This function initialized the IUniswapV2Pair in the tested network.
     *
     * @param token0 address of the first token
     * @param token1 address of the second token
     *
     * @return pairAddress address of pair for provided addresses
     * @return pair IUniswapV2Pair for provided addresses
     */
    function _getUniswapPair(
        address token0,
        address token1
    ) private view returns (address pairAddress, IUniswapV2Pair pair) {
        pairAddress = _getUniswapFactory().getPair(token0, token1);
        require(pairAddress != address(0), "Ivalid IUniswapV2Pair address");

        pair = IUniswapV2Pair(pairAddress);
    }

    /**
     * This function initializes the IUniswapV2Factory in the tested network.
     */
    function _getUniswapFactory()
        private
        pure
        returns (IUniswapV2Factory factory)
    {
        address factory_address = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
        factory = IUniswapV2Factory(factory_address);
    }
}
