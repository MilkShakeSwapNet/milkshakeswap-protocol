// Declare this file as a StarkNet contract.
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_equal
from starkware.cairo.common.uint256 import uint256_signed_le, Uint256
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.hash import hash2

from openzeppelin.token.erc20.library import ERC20
from openzeppelin.token.erc20.IERC20 import IERC20
from openzeppelin.security.safemath.library import SafeUint256

const MINIMUM_LIQUIDITY = 1000;

// Define a storage variable.
@storage_var
func tokenA_store() -> (tokenA: felt) {
}

@storage_var
func tokenB_store() -> (tokenB: felt) {
}

@storage_var
func reserve0_store() -> (reserve0: Uint256) {
}

@storage_var
func reserve1_store() -> (reserve1: Uint256) {
}

@storage_var
func amount0_store() -> (amount0In: Uint256) {
}

@storage_var
func amount1_store() -> (amount1In: Uint256) {
}

@storage_var
func liquidity_store() -> (liquidity: Uint256) {
}

@event
func emit(sender: felt, amount0: felt, amount1: felt) {
}

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

@external
func getReserves{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    _reserve0: Uint256, _reserve1: Uint256
) {
    let (_reserve0) = reserve0_store.read();
    let (_reserve1) = reserve1_store.read();

    return (_reserve0, _reserve1);
}

func _update{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    balance0: Uint256, balance1: Uint256, _reserve0: Uint256, _reserver1: Uint256
) {
    // Understand what is cumulative and block timestamp. What is the relation with time
    reserve0_store.write(balance0);
    reserve1_store.write(balance1);

    return ();
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _tokenA: felt, _tokenB: felt
) {
    // assert that is being called from factory
    tokenA_store.write(_tokenA);
    tokenB_store.write(_tokenB);

    return ();
}

// @external
// func initialize{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(_tokenA: felt,
//         _tokenB: felt):
//     # assert that is being called from factory
//     tokenA_store.write(_tokenA)
//     tokenB_store.write(_tokenB)

// return ()
// end

@external
func mint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(to: felt) -> (
    liquidity: Uint256
) {
    alloc_locals;
    let (_reserve0, _reserve1) = getReserves();
    let (caller) = get_caller_address();
    let (tokenA) = tokenA_store.read();
    let (tokenB) = tokenB_store.read();
    // Do I have to initialize with ERC20 function
    // let ERC20balance0 = ERC20.initializer('tokenA', tokenA, 10**8)
    // let (balance0) = ERC20.balance_of(caller)
    // token A contract
    let (balance0) = IERC20.balanceOf(tokenA, caller);

    // let ERC20balance1 = ERC20.initializer('tokenB', tokenB, 10**8)
    // token B contract
    let (balance1) = IERC20.balanceOf(tokenB, caller);

    // let _reserve0_uint256 = Uint256(low=_reserve0, high=0)
    let (amount0) = SafeUint256.sub_le(_reserve0, balance0);

    // let _reserve1_uint256 = Uint256(low=_reserve1, high=0)
    let (amount1) = SafeUint256.sub_le(_reserve1, balance1);

    // add fees on this. Mint feeds

    // what is address0

    // Add condition of total supply as 0
    // address this vs address to
    let (_totalSupply) = ERC20.total_supply();

    let (m0) = SafeUint256.mul(amount0, _totalSupply);
    let (m1) = SafeUint256.mul(amount1, _totalSupply);

    let (cmp0, rem0) = SafeUint256.div_rem(m0, _reserve0);
    let (cmp1, rem1) = SafeUint256.div_rem(m1, _reserve0);
    let (compare) = uint256_signed_le(cmp0, cmp1);
    if (compare == 1) {
        liquidity_store.write(cmp0);
    } else {
        liquidity_store.write(cmp1);
    }

    let (lq) = liquidity_store.read();
    ERC20._mint(to, lq);

    _update(balance0, balance1, _reserve0, _reserve1);

    return (lq,);
}

@external
func burn{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(to: felt) -> (
    amount0: Uint256, amount1: Uint256
) {
    alloc_locals;
    let (_reserve0, _reserve1) = getReserves();
    let (_token0) = tokenA_store.read();
    let (_token1) = tokenB_store.read();
    let (caller) = get_caller_address();

    // let ERC20balance0 = ERC20.initializer('tokenA', _token0, 10**8)
    // let (balance0) = ERC20.balance_of(caller)
    let (balance0) = IERC20.balanceOf(_token0, caller);
    // let ERC20balance1 = ERC20.initializer('tokenB', _token1, 10**8)
    // let (balance1) = ERC20.balance_of(caller)
    let (balance1) = IERC20.balanceOf(_token1, caller);

    let (liquidity) = ERC20.balance_of(caller);
    let (_totalSupply) = ERC20.total_supply();

    let (m0) = SafeUint256.mul(liquidity, balance0);
    let (m1) = SafeUint256.mul(liquidity, balance1);
    let (amount0, rem0) = SafeUint256.div_rem(m0, _totalSupply);
    let (amount1, rem1) = SafeUint256.div_rem(m1, _totalSupply);

    ERC20._burn(caller, liquidity);
    IERC20.transferFrom(_token0, caller, to, amount0);
    IERC20.transferFrom(_token1, caller, to, amount1);

    // let (new_balance0) =  ERC20.balance_of(to)
    let (new_balance0) = IERC20.balanceOf(_token0, caller);
    // let (new_balance1) =  ERC20.balance_of(to)
    let (new_balance1) = IERC20.balanceOf(_token1, caller);

    _update(new_balance0, new_balance1, _reserve0, _reserve1);

    return (new_balance0, new_balance1);
}

@external
func swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount0Out: Uint256, amount1Out: Uint256, to: felt
) {
    alloc_locals;

    let (_token0) = tokenA_store.read();
    let (_token1) = tokenB_store.read();
    let (_reserve0, _reserve1) = getReserves();
    let (caller) = get_caller_address();

    IERC20.transferFrom(_token0, caller, to, amount0Out);
    IERC20.transferFrom(_token1, caller, to, amount1Out);

    // let ERC20balance0 = ERC20.initializer('tokenA', _token0, 10**8)
    // let (balance0) = ERC20.balance_of(caller)
    let (balance0) = IERC20.balanceOf(_token0, caller);

    // let ERC20balance1 = ERC20.initializer('tokenB', _token1, 10**8)
    // let (balance1) = ERC20.balance_of(caller)
    let (balance1) = IERC20.balanceOf(_token1, caller);

    let (remainingReserve0) = SafeUint256.sub_le(_reserve0, amount0Out);
    let (remainingReserve1) = SafeUint256.sub_le(_reserve1, amount1Out);

    let (compare0) = uint256_signed_le(remainingReserve0, balance0);
    let (tsub0) = SafeUint256.sub_le(_reserve0, amount0Out);
    let (famount0In) = SafeUint256.sub_le(balance0, tsub0);

    if (compare0 == 1) {
        amount0_store.write(famount0In);
    } else {
        amount0_store.write(Uint256(low=0, high=0));
    }

    local syscall_ptr: felt* = syscall_ptr;
    local pedersen_ptr: HashBuiltin* = pedersen_ptr;

    let (compare1) = uint256_signed_le(remainingReserve1, balance1);
    let (tsub1) = SafeUint256.sub_le(_reserve1, amount1Out);
    let (famount1In) = SafeUint256.sub_le(balance1, tsub1);

    if (compare1 == 1) {
        amount1_store.write(famount1In);
    } else {
        amount1_store.write(Uint256(low=0, high=0));
    }

    let (m00) = SafeUint256.mul(balance0, Uint256(low=1000, high=0));
    let (amount0In) = amount0_store.read();
    let (m01) = SafeUint256.mul(amount0In, Uint256(low=3, high=0));
    let (m10) = SafeUint256.mul(balance1, Uint256(low=1000, high=0));
    let (amount1In) = amount0_store.read();
    let (m11) = SafeUint256.mul(amount1In, Uint256(low=3, high=0));

    let (balance0Adj) = SafeUint256.sub_le(m00, m01);
    let (balance1Adj) = SafeUint256.sub_le(m10, m11);

    _update(balance0, balance1, _reserve0, _reserve1);

    return ();
}
