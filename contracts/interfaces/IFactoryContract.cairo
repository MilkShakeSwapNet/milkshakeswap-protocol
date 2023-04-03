// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.1.0 (token/erc20/interfaces/IERC20.cairo)

%lang starknet

@contract_interface
namespace IFactoryContract {
    func create_pair(tokenA: felt, tokenB: felt) {
    }

    func get_pair(tokenA: felt, tokenB: felt) -> (res: felt) {
    }
}
