# Token bridge tutorial

This is running through the token bridge tutorial off of aztec-packages `0.45.1` branch on July 8th.

## Requirements

- node.js version 18.x.x
- Aztec sandbox, install with:

```bash
  bash -i <(curl -s install.aztec.network)
```

## Testing

### Update

Use 0.45.1 build for `aztec-up`:

```bash
aztec-up
```

or

```bash
VERSION=0.45.1 aztec-up
```

#### Dependencies

- Update dependencies in Nargo.toml in `packages/aztec-contracts/token_bridge` to your version.
- Update @aztec package versions in `packages/src/package.json` to your version.

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

:warning: You might need to restart the sandbox between testing runs, since the test will produce the same note commitments and nullifiers, which the sequencer will reject.

Run the sandbox

```bash
aztec-sandbox
```

Run the tests

```bash
cd packages/src
yarn
DEBUG='aztec:e2e_uniswap' yarn test
DEBUG='aztec:*' yarn test
```
