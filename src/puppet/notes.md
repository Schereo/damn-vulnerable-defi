# Notes

I guess this is again about oracle manipulation.

The price behaves in reverse than expected. If looked at the `_computeOraclePrice()` function, it can be seen that with increased DVT balance in the uniswap v1 exchange the computed oracle price decreases. Therefore DVT needs to be put into
the exchange to decrease the oracle price.

```javascript
function _computeOraclePrice() private view returns (uint256) {
        // calculates the price of the token in wei according to Uniswap pair
        return uniswapPair.balance * (10 ** 18) / token.balanceOf(uniswapPair);
    }
```


// 2000000000000000000
// 196643298887982