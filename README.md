SimpleSwap - Automated Market Maker (AMM)

Este repositorio contiene un contrato inteligente llamado SimpleSwap, que implementa un market maker automatizado simplificado inspirado en Uniswap V2. Fue desarrollado con fines educativos.

✨ Características principales

Agregar liquidez: addLiquidity

Retirar liquidez: removeLiquidity

Intercambiar tokens: swapExactTokensForTokens

Consultar el precio entre pares: getPrice

Calcular montos de salida esperados: getAmountOut

Incluye además un contrato verificador llamado SwapVerifier para realizar pruebas automáticas sobre instancias desplegadas de SimpleSwap.


🧱 Ejemplo de interacción (Etherscan)

addLiquidity(...)

tokenA: Dirección del primer token

tokenB: Dirección del segundo token

amountADesired / amountBDesired: Cantidades a depositar

amountAMin / amountBMin: Mínimo aceptado para cada token

to: Dirección que recibirá los tokens de liquidez

deadline: Timestamp de expiración

swapExactTokensForTokens(...)

amountIn: Monto a intercambiar

amountOutMin: Mínimo aceptado de salida

path: Arreglo con [tokenA, tokenB]

to: Destinatario de los tokens

deadline: Timestamp límite

🔧 Compilación (avanzado)

Si usás Hardhat:

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      viaIR: true
    }
  }
};

🕊️ Autor

Desarrollado por Hipólito Alonso como parte de un trabajo práctico para formación en desarrollo de smart contracts.
