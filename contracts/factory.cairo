// Declare this file as a StarkNet contract.
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
// from starkware.cairo.common.cairo_keccak.keccak import keccak_felts
from starkware.cairo.common.math import assert_not_equal
from starkware.cairo.common.uint256 import uint256_signed_le, Uint256
from starkware.cairo.common.hash import hash2
from starkware.starknet.common.syscalls import deploy
from starkware.cairo.common.bool import FALSE
// from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
// from starkware.starknet.core.os.contract_address import get_contract_address

// Define a storage variable.
@storage_var
func pair_store(tokenA: felt, tokenB: felt) -> (pair: felt) {
}

@storage_var
func all_pair() -> (pair: felt) {
}

@storage_var
func contract_class_hash() -> (pair: felt) {
}

@storage_var
func pair_store_length() -> (pair_length: felt) {
}

@event
func pair_created(token0: felt, token1: felt, pair: felt, pair_length: felt) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    class_hash: felt
) {
    contract_class_hash.write(class_hash);
    return ();
}

@external
func create_pair{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    tokenA: felt, tokenB: felt
) {
    alloc_locals;
    let token0 = tokenA;
    let token1 = tokenB;

    // let tokenA_Uint256 = Uint256(low=tokenA, high=0)
    // let tokenB_Uint256 = Uint256(low=tokenB, high=0)
    // let (v) = uint256_signed_le(tokenA_Uint256, tokenB_Uint256)
    // if v == 1:
    //     token0 = tokenA
    //     token1 = tokenB
    // else:
    //     token0 = tokenB
    //     token1 = tokenA
    // end

    let (hash) = hash2{hash_ptr=pedersen_ptr}(token0, token1);
    let (class_hash) = contract_class_hash.read();

    let (pair) = deploy(
        class_hash=class_hash,
        contract_address_salt=hash,
        constructor_calldata_size=2,
        constructor_calldata=cast(new (token0, token1), felt*),
        deploy_from_zero=FALSE,
    );

    // add initialize pair from pair contract
    pair_store.write(token0, token1, pair);
    pair_store.write(token1, token0, pair);
    all_pair.write(pair);
    let (cur_all_pair_len) = pair_store_length.read();
    pair_store_length.write(cur_all_pair_len + 1);
    let (len) = pair_store_length.read();
    pair_created.emit(token0, token1, pair, len);

    return ();
}

@view
func get_pair{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    tokenA: felt, tokenB: felt
) -> (pair: felt) {
    let (pair) = pair_store.read(tokenA, tokenB);
    return (pair,);
}
