# fraise-protocol

Smart contracts for the Fraise platform, deployed on Optimism.

## Contracts

| Contract | Description |
|---|---|
| `FraiseIdentity` | Registry linking `fraise.box` labels to Optimism wallet addresses |
| `FraiseNFC` | Records NFC scan events on-chain and issues time credits per scan |
| `FraiseTimeCredits` | Time credit ledger — credited by `FraiseNFC` on each verified scan |
| `FraiseToken` | Platform token |
| `FraisePayments` | Payment processing |

## Related repos

- [`fraise-device`](https://github.com/q04-oss/fraise-device) — Cardputer firmware (ESP32-S3, C++/PlatformIO)
- [`box-fraise`](https://github.com/q04-oss/box-fraise) — iOS app and API

## Development

Built with [Foundry](https://book.getfoundry.sh/).

```shell
forge build
forge test
forge fmt
```

### Environment

```shell
cp .env.example .env
# Set OPTIMISM_RPC_URL, OP_SEPOLIA_RPC_URL, ETHERSCAN_API_KEY, DEPLOYER_PRIVATE_KEY
```

### Deploy

```shell
# Sepolia testnet
forge script contracts/script/DeploySepolia.s.sol --rpc-url sepolia --broadcast --verify

# Mainnet
forge script contracts/script/Deploy.s.sol --rpc-url optimism --broadcast --verify
```
