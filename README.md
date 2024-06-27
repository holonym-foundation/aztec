# Token bridge tutorial

This is running through the token bridge tutorial off of aztec-packages `0.42.0` branch on June 11th.

## Install aztec
  
```bash
  bash -i <(curl -s install.aztec.network)
```

## Testing

### Update

Use 0.42.0 build for `aztec-up`:

```bash
aztec-up
```

### Compile

#### Aztec contracts

```bash
cd packages/aztec-contracts/token_bridge
aztec-nargo compile
# the output is already committed in this repo, but you'll have to rerun this if you change anything in the contract
aztec-builder codegen target -o ../../src/test/fixtures
```

#### L1 contracts

```bash
cd l1-contracts
yarn
npx hardhat compile
```

### Run

Run the sandbox

```bash
aztec-sandbox
```

Run the tests

```bash
cd packages/src
yarn
DEBUG='aztec:e2e_uniswap' yarn test
```
