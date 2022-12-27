# Solidity Flash Loans

*Author*: Igor Podtsepko (i.podtsepko2002@gmail.com).

## Requirements

Before running the program, you need to install the required JS modules. Use the `npm install` to do this.

## Running tests

Example of running tests:

```
$ npx hardhat test


  Flash swap test
    Borrowed tokens swapped on 842928549 wETH
    flashLoan.uniswapV2Call
        ✓ Swap maked: 842928549 wETH -> 165787095900 LINK
        ✓ Swap maked: 165787095900 LINK -> 977892379255 DAI
        ✓ Swap maked: 977892379255 DAI -> 824742285 wETH

        After a cyclic flash loan, 824742285 wETH remained
        Losses: 18186264 wETH
    ✔ An attempt of cyclic flash loan has been made (2551ms)


  1 passing (3s)

```
