// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title SimpleSwap - Automated Market Maker (AMM) for ERC20 token pairs
/// @author Hipolito
/// @notice Enables liquidity provision and token swaps without fees
/// @dev Suitable for educational use. Assumes ERC20-compliant tokens
interface IERC20 {
    /// @notice Emitted when tokens are transferred
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice Emitted when a new allowance is set
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /// @notice Returns total supply of tokens
    function totalSupply() external view returns (uint256);

    /// @notice Returns the balance of a specific account
    /// @param account The address to query
    function balanceOf(address account) external view returns (uint256);

    /// @notice Transfers tokens to another address
    /// @param to Recipient address
    /// @param value Amount to transfer
    function transfer(address to, uint256 value) external returns (bool);

    /// @notice Returns remaining allowance for a spender
    /// @param owner The address which owns the tokens
    /// @param spender The address allowed to spend
    function allowance(address owner, address spender) external view returns (uint256);

    /// @notice Approves spender to transfer up to value tokens
    /// @param spender The address to approve
    /// @param value The amount allowed
    function approve(address spender, uint256 value) external returns (bool);

    /// @notice Transfers tokens using allowance mechanism
    /// @param from Source address
    /// @param to Destination address
    /// @param value Amount to transfer
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

contract SimpleSwap {
    /// @notice Struct to hold reserves of token pairs
    struct Reserves {
        uint256 reserveA;
        uint256 reserveB;
    }

    /// @notice Mapping from pair key to reserves
    mapping(bytes32 => Reserves) public reserves;

    /// @notice Mapping from pair key to total liquidity
    mapping(bytes32 => uint256) public totalLiquidity;

    /// @notice Mapping from pair key to address's liquidity balance
    mapping(bytes32 => mapping(address => uint256)) public liquidityBalance;

    /// @notice Computes unique key for token pair
    /// @param tokenA Address of first token
    /// @param tokenB Address of second token
    /// @return key Unique hash for token pair
    function pairKey(address tokenA, address tokenB) internal pure returns (bytes32 key) {
        key = tokenA < tokenB
            ? keccak256(abi.encodePacked(tokenA, tokenB))
            : keccak256(abi.encodePacked(tokenB, tokenA));
    }

    /// @notice Adds liquidity to a pair
    /// @param tokenA Address of token A
    /// @param tokenB Address of token B
    /// @param amountADesired Desired amount of token A
    /// @param amountBDesired Desired amount of token B
    /// @param amountAMin Minimum amount of token A
    /// @param amountBMin Minimum amount of token B
    /// @param to Recipient of liquidity tokens
    /// @param deadline Expiry timestamp
    /// @return amountA Amount of token A added
    /// @return amountB Amount of token B added
    /// @return liquidity Liquidity tokens minted
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        require(block.timestamp <= deadline, "Deadline expired");

        bytes32 key = pairKey(tokenA, tokenB);
        Reserves storage r = reserves[key];

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountADesired);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountBDesired);

        amountA = amountADesired;
        amountB = amountBDesired;

        require(amountA >= amountAMin && amountB >= amountBMin, "Insufficient input amounts");

        liquidity = amountA + amountB;
        totalLiquidity[key] += liquidity;
        liquidityBalance[key][to] += liquidity;

        r.reserveA += amountA;
        r.reserveB += amountB;
    }

    /// @notice Removes liquidity from a pair
    /// @param tokenA Address of token A
    /// @param tokenB Address of token B
    /// @param liquidity Amount to remove
    /// @param amountAMin Minimum token A expected
    /// @param amountBMin Minimum token B expected
    /// @param to Recipient address
    /// @param deadline Expiry timestamp
    /// @return amountA Token A withdrawn
    /// @return amountB Token B withdrawn
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB) {
        require(block.timestamp <= deadline, "Deadline expired");

        bytes32 key = pairKey(tokenA, tokenB);
        require(liquidityBalance[key][msg.sender] >= liquidity, "Not enough liquidity");

        Reserves storage r = reserves[key];
        uint256 totalLiq = totalLiquidity[key];

        amountA = (r.reserveA * liquidity) / totalLiq;
        amountB = (r.reserveB * liquidity) / totalLiq;

        require(amountA >= amountAMin && amountB >= amountBMin, "Too little received");

        r.reserveA -= amountA;
        r.reserveB -= amountB;
        totalLiquidity[key] -= liquidity;
        liquidityBalance[key][msg.sender] -= liquidity;

        IERC20(tokenA).transfer(to, amountA);
        IERC20(tokenB).transfer(to, amountB);
    }

    /// @notice Swaps input tokens for output tokens in a pair
    /// @param amountIn Input amount
    /// @param amountOutMin Minimum output expected
    /// @param path Array of [tokenIn, tokenOut]
    /// @param to Recipient of output tokens
    /// @param deadline Expiry timestamp
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external {
        require(block.timestamp <= deadline, "Deadline expired");
        require(path.length == 2, "Only 2-token swaps supported");

        address tokenIn = path[0];
        address tokenOut = path[1];
        _executeSwap(tokenIn, tokenOut, amountIn, amountOutMin, to);
    }

    /// @dev Internal function to execute the token swap
    /// @param tokenIn Token being swapped in
    /// @param tokenOut Token being received
    /// @param amountIn Amount of tokenIn
    /// @param amountOutMin Minimum acceptable amount of tokenOut
    /// @param to Recipient of tokenOut
    function _executeSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) internal {
        bytes32 key = pairKey(tokenIn, tokenOut);
        Reserves storage r = reserves[key];

        uint256 reserveIn = tokenIn < tokenOut ? r.reserveA : r.reserveB;
        uint256 reserveOut = tokenIn < tokenOut ? r.reserveB : r.reserveA;

        uint256 amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= amountOutMin, "Slippage too high");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).transfer(to, amountOut);

        if (tokenIn < tokenOut) {
            r.reserveA += amountIn;
            r.reserveB -= amountOut;
        } else {
            r.reserveB += amountIn;
            r.reserveA -= amountOut;
        }
    }

    /// @notice Returns price of tokenA in terms of tokenB
    /// @param tokenA Address of token A
    /// @param tokenB Address of token B
    /// @return price Current price with 18 decimals
    function getPrice(address tokenA, address tokenB) external view returns (uint256 price) {
        bytes32 key = pairKey(tokenA, tokenB);
        Reserves storage r = reserves[key];
        require(r.reserveA > 0 && r.reserveB > 0, "Empty reserves");

        price = (r.reserveB * 1e18) / r.reserveA;
    }

    /// @notice Calculates output amount from input and reserves
    /// @param amountIn Input token amount
    /// @param reserveIn Reserve of input token
    /// @param reserveOut Reserve of output token
    /// @return amountOut Calculated output token amount
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public pure returns (uint256 amountOut)
    {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "Invalid reserves");
        amountOut = (amountIn * reserveOut) / (amountIn + reserveIn);
    }
}
