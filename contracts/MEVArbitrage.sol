// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

interface IFlashLoanProvider {
    function flashLoan(address borrower, uint256 amount, address token) external;
}

contract MEVArbitrage is ReentrancyGuard {
    address public owner;
    IFlashLoanProvider public flashLoanProvider;
    IUniswapV2Router02 public uniswapRouter;
    address public weth;
    address public baseToken;

    event ArbitrageExecuted(uint256 profit, address token);

    constructor(address _flashLoanProvider, address _uniswapRouter, address _weth, address _baseToken) {
        owner = msg.sender;
        flashLoanProvider = IFlashLoanProvider(_flashLoanProvider);
        uniswapRouter = IUniswapV2Router02(_uniswapRouter);
        weth = _weth;
        baseToken = _baseToken;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function executeArbitrage(
        address token,
        uint256 loanAmount,
        address dex1,
        address dex2
    ) external nonReentrant onlyOwner {
        flashLoanProvider.flashLoan(address(this), loanAmount, token);
        uint256 profit = swapTokens(token, loanAmount, dex1, dex2);
        require(profit > 0, "No profit made");

        IERC20(token).transfer(owner, profit);
        emit ArbitrageExecuted(profit, token);
    }

    function swapTokens(
        address token,
        uint256 amount,
        address dex1,
        address dex2
    ) internal returns (uint256) {
        IERC20(token).approve(dex1, amount);
        address ;
        path[0] = token;
        path[1] = weth;

        uint256[] memory amountsOut = IUniswapV2Router02(dex1).swapExactTokensForTokens(
            amount,
            1,
            path,
            address(this),
            block.timestamp + 300
        );

        uint256 amountReceived = amountsOut[1];

        IERC20(weth).approve(dex2, amountReceived);
        address ;
        reversePath[0] = weth;
        reversePath[1] = token;

        uint256[] memory amountsBack = IUniswapV2Router02(dex2).swapExactTokensForTokens(
            amountReceived,
            1,
            reversePath,
            address(this),
            block.timestamp + 300
        );

        return amountsBack[1] - amount;
    }

    function withdrawTokens(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(owner, balance);
    }
}
