// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title SimpleSwap - A basic AMM smart contract for ERC20 token pairs
/// @author Hipolito Alonso
/// @notice Allows adding/removing liquidity, swapping tokens, querying prices and expected output
contract SimpleSwap {
    uint256 private constant FEE_NUMERATOR = 997;
    uint256 private constant FEE_DENOMINATOR = 1000;

    struct Reserves {
        uint112 reserve0;
        uint112 reserve1;
    }

    mapping(bytes32 => Reserves) private reserves;
    mapping(bytes32 => uint256) private totalLiquidity;
    mapping(bytes32 => mapping(address => uint256)) private liquidityBalance;

    event LiquidityAdded(address indexed provider, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, address indexed tokenA, address indexed tokenB, uint256 amountA, uint256 amountB);
    event Swapped(address indexed trader, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);

    /// @notice Adds liquidity to the pool
    /// @param tokenA First token address
    /// @param tokenB Second token address
    /// @param amountA Amount of tokenA to add
    /// @param amountB Amount of tokenB to add
    /// @param amountAMin Minimum acceptable amount of tokenA
    /// @param amountBMin Minimum acceptable amount of tokenB
    /// @param to Address that will receive the liquidity tokens
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) external {
        require(tokenA != tokenB, "Identical tokens");
        require(amountA >= amountAMin && amountB >= amountBMin, "Slippage limit");

        (address token0, address token1, uint256 amt0, uint256 amt1) = sortTokens(tokenA, tokenB, amountA, amountB);
        bytes32 pairHash = keccak256(abi.encodePacked(token0, token1));

        IERC20(token0).transferFrom(msg.sender, address(this), amt0);
        IERC20(token1).transferFrom(msg.sender, address(this), amt1);

        uint256 liquidity = amt0 + amt1; // Simplified logic for LP minting
        totalLiquidity[pairHash] += liquidity;
        liquidityBalance[pairHash][to] += liquidity;

        reserves[pairHash].reserve0 += uint112(amt0);
        reserves[pairHash].reserve1 += uint112(amt1);

        emit LiquidityAdded(to, token0, token1, amt0, amt1, liquidity);
    }

    /// @notice Removes liquidity from the pool
    /// @param tokenA First token address
    /// @param tokenB Second token address
    /// @param liquidity Amount of liquidity to remove
    function removeLiquidity(address tokenA, address tokenB, uint256 liquidity) external {
        (address token0, address token1, , ) = sortTokens(tokenA, tokenB, 0, 0);
        bytes32 pairHash = keccak256(abi.encodePacked(token0, token1));

        require(liquidityBalance[pairHash][msg.sender] >= liquidity, "Insufficient liquidity");

        uint256 totalLiq = totalLiquidity[pairHash];
        uint256 amt0 = reserves[pairHash].reserve0 * liquidity / totalLiq;
        uint256 amt1 = reserves[pairHash].reserve1 * liquidity / totalLiq;

        liquidityBalance[pairHash][msg.sender] -= liquidity;
        totalLiquidity[pairHash] -= liquidity;

        reserves[pairHash].reserve0 -= uint112(amt0);
        reserves[pairHash].reserve1 -= uint112(amt1);

        IERC20(token0).transfer(msg.sender, amt0);
        IERC20(token1).transfer(msg.sender, amt1);

        emit LiquidityRemoved(msg.sender, token0, token1, amt0, amt1);
    }

    /// @notice Swaps an exact amount of tokenIn for tokenOut
    /// @param tokenIn Address of token sent
    /// @param tokenOut Address of token received
    /// @param amountIn Amount of tokenIn sent
    /// @param to Address that receives tokenOut
    function swapExactTokensForTokens(address tokenIn, address tokenOut, uint256 amountIn, address to) external {
        require(tokenIn != tokenOut, "Identical tokens");

        (address token0, address token1, , ) = sortTokens(tokenIn, tokenOut, 0, 0);
        bytes32 pairHash = keccak256(abi.encodePacked(token0, token1));

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        (uint112 reserve0, uint112 reserve1) = (reserves[pairHash].reserve0, reserves[pairHash].reserve1);
        (uint256 resIn, uint256 resOut) = tokenIn == token0 ? (reserve0, reserve1) : (reserve1, reserve0);

        uint256 amountInWithFee = amountIn * FEE_NUMERATOR;
        uint256 numerator = amountInWithFee * resOut;
        uint256 denominator = resIn * FEE_DENOMINATOR + amountInWithFee;
        uint256 amountOut = numerator / denominator;

        require(amountOut > 0, "Insufficient output amount");

        address outToken = tokenIn == token0 ? token1 : token0;
        IERC20(outToken).transfer(to, amountOut);

        if (tokenIn == token0) {
            reserves[pairHash].reserve0 += uint112(amountIn);
            reserves[pairHash].reserve1 -= uint112(amountOut);
        } else {
            reserves[pairHash].reserve1 += uint112(amountIn);
            reserves[pairHash].reserve0 -= uint112(amountOut);
        }

        emit Swapped(msg.sender, tokenIn, outToken, amountIn, amountOut);
    }

    /// @notice Returns price of tokenA in terms of tokenB
    function getPrice(address tokenA, address tokenB) external view returns (uint256) {
        (address token0, address token1, , ) = sortTokens(tokenA, tokenB, 0, 0);
        bytes32 pairHash = keccak256(abi.encodePacked(token0, token1));
        (uint112 reserve0, uint112 reserve1) = (reserves[pairHash].reserve0, reserves[pairHash].reserve1);
        return tokenA == token0 ? (reserve1 * 1e18) / reserve0 : (reserve0 * 1e18) / reserve1;
    }

    /// @notice Returns expected output tokens for a given input
    function getAmountOut(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256) {
        (address token0, address token1, , ) = sortTokens(tokenIn, tokenOut, 0, 0);
        bytes32 pairHash = keccak256(abi.encodePacked(token0, token1));
        (uint112 reserve0, uint112 reserve1) = (reserves[pairHash].reserve0, reserves[pairHash].reserve1);
        (uint256 resIn, uint256 resOut) = tokenIn == token0 ? (reserve0, reserve1) : (reserve1, reserve0);

        uint256 amountInWithFee = amountIn * FEE_NUMERATOR;
        uint256 numerator = amountInWithFee * resOut;
        uint256 denominator = resIn * FEE_DENOMINATOR + amountInWithFee;
        return numerator / denominator;
    }

    /// @notice Returns liquidity balance of a user
    function liquidityBalanceOf(address tokenA, address tokenB, address user) external view returns (uint256) {
        (address token0, address token1, , ) = sortTokens(tokenA, tokenB, 0, 0);
        bytes32 pairHash = keccak256(abi.encodePacked(token0, token1));
        return liquidityBalance[pairHash][user];
    }

    function sortTokens(address tokenA, address tokenB, uint256 amountA, uint256 amountB) internal pure returns (address, address, uint256, uint256) {
        return tokenA < tokenB ? (tokenA, tokenB, amountA, amountB) : (tokenB, tokenA, amountB, amountA);
    }
}
