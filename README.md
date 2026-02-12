# Pennysia AMM V1-Periphery

[![Solidity](https://img.shields.io/badge/Solidity-0.8.28-blue.svg)](https://docs.soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-red.svg)](https://getfoundry.sh/)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL%203.0-blue.svg)](#-license)
[![CI](https://github.com/Pennysia/v1-periphery/actions/workflows/test.yml/badge.svg)](https://github.com/Pennysia/v1-periphery/actions/workflows/test.yml)

## ⚠️ Repository Status & Safety Notice

This repository is archived. The code was created solely to compete in the Sonic Hackathon in August 2026. It has **not** undergone any security audits and may contain serious bugs or vulnerabilities. **Do not use this code in production or to secure real funds.**

> **The official periphery package for the [Pennysia AMM v1-core](https://github.com/Pennysia/v1-core): a robust, modular router and utility library for advanced swaps, liquidity management, and seamless integration with the core protocol.**

---

## Table of Contents

- [Project Introduction](#project-introduction)
- [Key Features](#-key-features)
- [Architecture](#-architecture)
- [How It Integrates with v1-core](#-how-it-integrates-with-v1-core)
- [Main Components](#-main-components)
- [Usage Example](#-usage-example)
- [Quick Start](#quick-start)
- [Requirements](#requirements)
- [Testing](#-testing)
- [Security](#-security)
- [License](#-license)
- [Contributing](#contributing)
- [Community & Contact](#community--contact)

---

## Project Introduction

**Pennysia AMM V1-Periphery** is the user-facing layer of the Pennysia protocol, providing a universal Router contract, utility libraries, and interfaces for seamless integration with the [Pennysia v1-core](https://github.com/Pennysia/v1-core) AMM. **Note:** v1-core and v1-periphery are maintained in separate GitHub repositories for modularity and clarity. This package is ideal for frontend developers, integrators, and anyone building on top of the Pennysia AMM.

---

## 🌟 Key Features

- **Universal Router**:  
  - Add/remove liquidity, swap, and interact with the core Market contract via a single interface.
  - Handles slippage, deadlines, and native/ETH sweeping.
- **Composable Libraries**:  
  - `RouterLibrary` for safe math, path routing, quoting, and validation.
  - `TransferHelper` for safe ERC20 and ETH transfers.
- **Interface-Driven**:  
  - Clean, extensible interfaces for routers, markets, liquidity tokens, and payments.
- **Security-First**:  
  - Deadline enforcement, slippage checks, and safe transfer patterns.
- **Plug-and-Play**:  
  - Designed for integration with the v1-core Market and custom frontends.

---

## 🏗️ Architecture

```
src/
├── Router.sol                 # 🛣️ Main router contract for swaps, liquidity, and payments
├── abstract/
│   ├── Deadline.sol           # ⏰ Deadline enforcement modifier
│   └── Multicall.sol          # 📞 Batched multicall execution
├── interfaces/
│   ├── IRouter.sol            # 🛣️ Router interface
│   ├── IMarket.sol            # 🏪 Market interface (core)
│   ├── ILiquidity.sol         # 🎫 LP token interface
│   ├── IPayment.sol           # 💰 Payment callback interface
│   ├── IMulticall.sol         # 📞 Multicall interface
│   └── IERC20.sol             # 🪙 Minimal ERC20 interface
├── libraries/
│   ├── RouterLibrary.sol      # 🧮 Math, quoting, path, and validation utilities
│   ├── TransferHelper.sol     # 💸 Safe ETH/ERC20 transfer helpers
│   └── Math.sol               # 🧮 Full-precision math (Solady)
```

---

## 🤝 How It Integrates with v1-core

Pennysia's **v1-periphery** is designed to work seamlessly with the [**Pennysia v1-core**](https://github.com/Pennysia/v1-core) package, which contains the core AMM logic in `Market.sol` and its supporting libraries and interfaces. **These are separate repositories:**
- v1-core: [https://github.com/Pennysia/v1-core](https://github.com/Pennysia/v1-core)
- v1-core README: [https://github.com/Pennysia/v1-core/blob/main/README.md](https://github.com/Pennysia/v1-core/blob/main/README.md)

- **Router as the Gateway:**
  - The `Router` contract in v1-periphery acts as the main entry point for users and frontends.
  - It delegates all core AMM operations (add/remove liquidity, swaps, payment callbacks) to the singleton `Market` contract in v1-core.

- **Interface-Driven Integration:**
  - v1-periphery imports and uses the interfaces from v1-core (`IMarket`, `ILiquidity`, etc.) to ensure ABI compatibility and safe interaction.
  - All router operations are parameterized to work with any Market instance.

- **Library Utilities:**
  - `RouterLibrary` in v1-periphery uses the core's interfaces to fetch reserves, compute pair IDs, and perform AMM math, always querying the Market contract for up-to-date state.

- **Payment Callbacks:**
  - The router implements the `IPayment` interface, allowing the Market contract to request tokens or liquidity as part of atomic operations (e.g., mint, burn, swap, flash).

### **Typical Flow Example**

```solidity
// Deploy the Market (from v1-core) and Router (from v1-periphery)
Market market = new Market(owner);
Router router = new Router(address(market));

// Add liquidity via the router (delegates to Market)
router.addLiquidity(
    token0, token1,
    1000e18, 500e18, 1000e18, 500e18, // amounts
    900e18, 400e18, 900e18, 400e18,   // minimums
    msg.sender,
    block.timestamp + 1 hours
);

// Swap tokens via the router (delegates to Market)
address[] memory path = new address[](2);
path[0] = token0;
path[1] = token1;
router.swap(100e18, 95e18, path, msg.sender, block.timestamp + 1 hours);

// Remove liquidity via the router (delegates to Market)
router.removeLiquidity(
    token0, token1,
    100e18, 50e18, 100e18, 50e18,
    90e18, 90e18,
    msg.sender,
    block.timestamp + 1 hours
);
```

- **All state-changing operations are ultimately performed by the Market contract in v1-core.**
- **The router provides user-friendly batching, validation, and payment handling, while the core enforces invariants and manages liquidity.**

---

## 🚦 Main Components

### Router.sol
- **addLiquidity/removeLiquidity**: add/remove liquidity with slippage + deadline.
- **swap**: multi-hop swaps with min-out and deadline.
- **liquiditySwap**: rebalance LP between long/short within a pair with min-outs + deadline.
- **quoteLiquidity/quoteReserve**: compute LP tokens or reserves for given inputs.
- **getAmountsIn/getAmountsOut**: path-based quoting utilities.
- **sweepNative**: withdraw stuck ETH to a recipient.
- **requestToken/requestLiquidity**: payment callbacks for core integration.

### Libraries
- **RouterLibrary**:  
  - Path validation, token sorting, quoting, and AMM math.
  - Handles edge cases (zero reserves, unsorted tokens, invalid paths).
- **TransferHelper**:  
  - Safe ERC20 and ETH transfers, handling missing return values and reverts.
- **Math**:  
  - Full-precision multiplication/division for AMM calculations.

### Interfaces
- **IRouter**:  
  - Standard interface for all router operations.
- **IMarket**:  
  - Interface for the core Market contract.
- **ILiquidity**:  
  - Interface for LP tokens with long/short positions.
- **IPayment**:  
  - Callback interface for payment flows.
- **IERC20**:  
  - Minimal ERC20 interface for token operations.

### Abstracts
- **Deadline**:  
  - Modifier to enforce transaction deadlines and prevent stale operations.

---

## ✨ Usage Example

```solidity
// Deploy the Router with the Market address
Router router = new Router(address(market));

// Add liquidity
router.addLiquidity(
    token0, token1,
    1000e18, 500e18, 1000e18, 500e18, // amounts
    900e18, 400e18, 900e18, 400e18,   // minimums
    msg.sender,
    block.timestamp + 1 hours
);

// Swap tokens
address[] memory path = new address[](2);
path[0] = token0;
path[1] = token1;
router.swap(100e18, 95e18, path, msg.sender, block.timestamp + 1 hours);

// Remove liquidity
router.removeLiquidity(
    token0, token1,
    100e18, 50e18, 100e18, 50e18,
    90e18, 90e18,
    msg.sender,
    block.timestamp + 1 hours
);

// Rebalance LP positions (long/short) within a pair
(uint256 out0, uint256 out1) = router.liquiditySwap(
    token0,
    token1,
    /* longToShort0 */ true,
    /* liquidity0    */ 500_000,
    /* longToShort1 */ false,
    /* liquidity1    */ 0,
    /* minOut0       */ 490_000,
    /* minOut1       */ 0,
    msg.sender,
    block.timestamp + 1 hours
);
```

---

## Quick Start

```bash
# Install Foundry (if not already)
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone the repo and install dependencies
git clone https://github.com/Pennysia/v1-periphery.git
cd v1-periphery
forge install

# Build and test
forge build
forge test -vvv
```

---

## Requirements

- [Foundry](https://getfoundry.sh/) (for building and testing)
- Solidity 0.8.28
- Node.js (optional, for frontend integration)

---

## 🧪 Testing

- Comprehensive test suite using Foundry/Forge.
- Includes unit and integration tests for all router, library, and payment flows.
- Mocks for Market, Liquidity, and ERC20 contracts.

```bash
# Run all tests
forge test

# Run with verbose output
forge test -vvv
```

---

## 🔒 Security

- **Archived project notice**: This repository is archived and unaudited. Do not use in production or to secure real funds.
- **Slippage checks**: All liquidity and swap operations revert if minimums are not met.
- **Deadline enforcement**: Prevents stale transactions.
- **Safe transfers**: All token and ETH transfers use robust helper libraries.
- **Input validation**: Library functions revert on invalid paths, unsorted tokens, or zero amounts.

---

## 📜 License

All code in this package is licensed under **GPL-3.0-or-later**.

---

## Contributing

We welcome contributions! Please:

1. Fork the repository
2. Create a feature branch
3. Add comprehensive tests
4. Ensure all tests pass
5. Submit a pull request

- Follow Solidity style guide
- Write clear commit messages
- Add tests for new features
- Update documentation as needed

---

## Community & Contact

- [Pennysia v1-core GitHub](https://github.com/Pennysia/v1-core)
- [Pennysia v1-core README](https://github.com/Pennysia/v1-core/blob/main/README.md)
- [Foundry Documentation](https://book.getfoundry.sh/)
- For commercial licensing or support, contact: [dev@pennysia.com](mailto:dev@pennysia.com)

---

**Built with ❤️ by the Pennysia Team**
