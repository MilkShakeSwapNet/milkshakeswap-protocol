// Declare this file as a StarkNet contract.
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
// from starkware.cairo.common.cairo_keccak.keccak import keccak_felts
from starkware.cairo.common.math import assert_not_equal
from starkware.cairo.common.uint256 import uint256_eq, uint256_signed_le, Uint256
from starkware.cairo.common.hash import hash2
from starkware.starknet.common.syscalls import deploy
from starkware.cairo.common.alloc import alloc
from openzeppelin.security.safemath.library import SafeUint256
// from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
// from starkware.starknet.core.os.contract_address import get_contract_address

// from core.library import (IFactoryContract)
from core.interfaces.IPairContract import IPairContract
from core.interfaces.IFactoryContract import IFactoryContract

@storage_var
func f_store() -> (factory: felt) {
}

@storage_var
func amount0Out_store() -> (amount0Out: Uint256) {
}

@storage_var
func amount1Out_store() -> (amount1Out: Uint256) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    factory_address: felt
) {
    f_store.write(factory_address);
    return ();
}

func quote{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amountA: Uint256, reserveA: Uint256, reserveB: Uint256
) -> (amountB: Uint256) {
    let (mul) = SafeUint256.mul(amountA, reserveB);

    let (div, rem) = SafeUint256.div_rem(mul, reserveA);

    return (div,);
}

func sort_token{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    tokenA: felt, tokenB: felt
) -> (tokenA: felt, tokenB: felt) {
    alloc_locals;
    let tokenA_Uint256 = Uint256(low=tokenA, high=0);
    let tokenB_Uint256 = Uint256(low=tokenB, high=0);
    let (v) = uint256_signed_le(tokenA_Uint256, tokenB_Uint256);
    if (v == 1) {
        return (tokenA, tokenB);
    } else {
        return (tokenB, tokenA);
    }
}

func _swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amounts: Uint256*, path: felt*, path_size: felt, path_index: felt, _to: felt
) {
    alloc_locals;
    if (path_index == path_size - 1) {
        return ();
    }

    let input = path[path_index];
    let output = path[path_index + 1];
    let path_index_uint256 = Uint256(path_index, 0);
    let path_size_uint256 = Uint256(path_size - 2, 0);

    let (token0, _) = sort_token(input, output);
    let amountOut = amounts[path_index + 1];
    local to;

    let (factory) = f_store.read();

    let (main_pair) = IFactoryContract.get_pair(factory, input, output);
    let p = path[path_index + 1];
    let (pair) = IFactoryContract.get_pair(factory, output, p);

    if (input == token0) {
        amount0Out_store.write(Uint256(0, 0));
        amount1Out_store.write(amountOut);
    } else {
        amount0Out_store.write(amountOut);
        amount1Out_store.write(Uint256(0, 0));
    }

    local syscall_ptr: felt* = syscall_ptr;
    local pedersen_ptr: HashBuiltin* = pedersen_ptr;

    let (cmp) = uint256_signed_le(path_index_uint256, path_size_uint256);
    if (cmp == 1) {
        to = pair;
    } else {
        to = _to;
    }

    let (amount0Out) = amount0Out_store.read();
    let (amount1Out) = amount1Out_store.read();

    IPairContract.swap(main_pair, amount0Out, amount1Out, to);

    _swap(amounts, path, path_size, path_index + 1, _to);

    return ();
}

func get_amount_out{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amountIn: Uint256, reserveIn: Uint256, reserveOut: Uint256
) -> (amountOut: Uint256) {
    alloc_locals;

    let (amountInWithFee) = SafeUint256.mul(amountIn, Uint256(low=997, high=0));
    let (num) = SafeUint256.mul(amountInWithFee, reserveOut);
    let (mul1) = SafeUint256.mul(reserveIn, Uint256(low=1000, high=0));
    let (deno) = SafeUint256.add(reserveIn, amountInWithFee);

    let (amountOut, amountOutRem) = SafeUint256.div_rem(num, deno);

    return (amountOut,);
}

func _get_amount_out_rec{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amounts: Uint256*, path: felt*, path_size: felt, path_index: felt
) -> (amounts: Uint256*) {
    alloc_locals;
    if (path_index == path_size - 1) {
        return (amounts,);
    }

    let (factory) = f_store.read();
    let (pair) = IFactoryContract.get_pair(factory, path[path_index], path[path_index + 1]);

    let (reserve0, reserve1) = IPairContract.getReserves(pair);

    let (a) = get_amount_out(amounts[path_index], reserve0, reserve1);

    // amounts[path_index + 1] = a

    _get_amount_out_rec(amounts, path, path_size, path_index + 1);

    return (amounts,);
}

func _get_amounts_out{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amountIn: Uint256, path: felt*, path_size: felt
) -> (amounts: Uint256*) {
    alloc_locals;
    // let (amounts: felt*) = alloc()
    let (amounts: Uint256*) = alloc();
    local a: Uint256 = Uint256(0, 0);
    // amounts[0] = a

    let (amts) = _get_amount_out_rec(amounts, path, path_size, 0);

    return (amts,);
}

func _add_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    tokenA: felt,
    tokenB: felt,
    amountADesired: Uint256,
    amountBDesired: Uint256,
    amountAMin: Uint256,
    amountBMin: Uint256,
    to: felt,
) -> (amountA: Uint256, amountB: Uint256) {
    // create a pair

    alloc_locals;
    let (factory) = f_store.read();
    let (pair) = IFactoryContract.get_pair(factory, tokenA, tokenB);
    // check if pair exists or not andf then create pair
    IFactoryContract.create_pair(factory, tokenA, tokenB);

    let (pair) = IFactoryContract.get_pair(factory, tokenA, tokenB);

    let (reserve0, reserve1) = IPairContract.getReserves(pair);

    let (reserve0_is_zero) = uint256_eq(reserve0, Uint256(0, 0));
    let (reserve1_is_zero) = uint256_eq(reserve1, Uint256(0, 0));

    if (reserve0_is_zero == 1) {
        if (reserve1_is_zero == 1) {
            return (amountADesired, amountBDesired);
        }
    }

    let (amountBOpt) = quote(amountADesired, reserve0, reserve1);
    let (amountBOptCmp) = uint256_signed_le(amountBOpt, amountBDesired);

    if (amountBOptCmp == 1) {
        return (amountADesired, amountBOpt);
    } else {
        let (amountAOpt) = quote(amountBDesired, reserve1, reserve0);

        return (amountAOpt, amountBDesired);
    }
}

@external
func add_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    tokenA: felt,
    tokenB: felt,
    amountADesired: Uint256,
    amountBDesired: Uint256,
    amountAMin: Uint256,
    amountBMin: Uint256,
    to: felt,
    deadline: Uint256,
) -> (amountA: Uint256, amountB: Uint256, liquidity: Uint256) {
    let (amountA, amountB) = _add_liquidity(
        tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, to
    );
    let (factory) = f_store.read();
    let (pair) = IFactoryContract.get_pair(factory, tokenA, tokenB);

    // What is that safe trasnfer?? Will that be taken care by our own mint?
    // is instance of ERC20 and using function in that context?

    let (liquidity) = IPairContract.mint(pair, to);

    return (amountA, amountB, liquidity);
}

@external
func remove_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    tokenA: felt,
    tokenB: felt,
    amountADesired: Uint256,
    amountBDesired: Uint256,
    amountAMin: Uint256,
    amountBMin: Uint256,
    to: felt,
    deadline: Uint256,
) -> (amountA: Uint256, amountB: Uint256) {
    alloc_locals;
    let (factory) = f_store.read();
    let (pair) = IFactoryContract.get_pair(factory, tokenA, tokenB);

    let (sortToken0, _) = sort_token(tokenA, tokenB);

    // What is that safe trasnfer?? Will that be taken care by our own mint?
    // is instance of ERC20 and using function in that context?

    let (amount0, amount1) = IPairContract.burn(pair, to);

    if (tokenA == sortToken0) {
        return (amount0, amount1);
    } else {
        return (amount1, amount0);
    }
}

@external
func swapExactTokensForTokens{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amountIn: Uint256,
    amountOutMin: Uint256,
    path_len: felt,
    path: felt*,
    to: felt,
    deadline: Uint256,
) -> (amounts_len: felt, amounts: Uint256*) {
    alloc_locals;
    let (amounts) = _get_amounts_out(amountIn, path, path_len);

    // safe transfer

    _swap(amounts, path, path_len, 0, to);
    return (path_len, amounts);
}
