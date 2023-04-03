// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.1.0 (token/erc20/interfaces/IERC20.cairo)

%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IPairContract {
    func getReserves() -> (reserve0: Uint256, reserve1: Uint256) {
    }

    func mint(to: felt) -> (liquidity: Uint256) {
    }

    func burn(to: felt) -> (amount0: Uint256, amount1: Uint256) {
    }

    func swap(amount0Out: Uint256, amount1Out: Uint256, to: felt) {
    }
}
