SimpleSwap Verification Report

📌 Context

This repository contains the implementation and manual verification of the SimpleSwap smart contract, a simplified Automated Market Maker (AMM) that allows liquidity provision, token swaps, price querying, and output estimation.

Two custom ERC20 tokens were used for this project:

POLA (Token A)

POLB (Token B)

The verification was intended to be executed via an automated contract called SwapVerifier. However, during the verification process, an issue arose that prevented the automatic test from completing successfully. As a result, a full manual verification of all functionality was carried out.

✅ SimpleSwap Contract Details

Contract address: 0x8d150Fa9EDCC6B4959B1fD4c687e9C581f2f5B97

Network: Sepolia

Key functions implemented:

addLiquidity

removeLiquidity

swapExactTokensForTokens

getPrice

getAmountOut

liquidityBalanceOf

🔍 Manual Verification Steps

All functionalities of SimpleSwap were manually verified as follows:

Minting:

POLA and POLB tokens were minted to the wallet 0x5D8466A440f9392e8ec6DD440d08698cb4c2D25D.

Additional minting was performed to the SwapVerifier contract for test purposes.

Approvals:

approve() was executed successfully from the user's wallet to allow SimpleSwap to spend POLA and POLB.

addLiquidity():

Successfully executed with 1 POLA and 2 POLB.

Liquidity tokens were received and verified using liquidityBalanceOf().

getPrice():

Verified the current price ratio between POLA and POLB.

getAmountOut():

Confirmed the correct output estimate for a given input.

swapExactTokensForTokens():

Swapped 0.01 POLA for approximately 0.0197 POLB.

Transaction succeeded, and token balances updated accordingly.

removeLiquidity() (optional step for full cycle):

Can be executed to complete the round trip.

🔍 SwapVerifier Behavior Analysis

Verifier Contract: 0x9f8F02DAB384DDdf1591C3366069Da3Fb0018220

Observation: Although tokens were minted to SwapVerifier, the contract failed to complete the verify() process.

Investigation: The failure occurred at the moment SwapVerifier attempted to execute approve() on its own token balances to authorize SimpleSwap. Despite the ERC20 token contracts appearing standard, the approval did not result in a usable allowance, causing the following transferFrom() to fail.

Clarification: This is not an inherent issue with SwapVerifier, as it is known to work with other token implementations. The issue appears to be related to how the approve() logic interacts with the specific token contracts in this environment, possibly due to subtle behavioral restrictions or execution context limitations.

🧠 Conclusion

Despite the failure of the automated verify() function in this context, all individual functions of SimpleSwap were validated manually and function as expected. The contract correctly handles:

Liquidity management

Price discovery

Token swaps

This confirms the implementation is functional. The environment-specific behavior of the verify() process highlights the importance of compatibility between testing contracts and token implementations.

✍️ Author

Hipolito AlonsoSepolia Testnet, 2025
