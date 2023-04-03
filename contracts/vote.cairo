// Declare this file as a StarkNet contract.
%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_equal, unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le_felt, is_le, is_not_zero
from starkware.cairo.common.uint256 import uint256_lt, Uint256, uint256_signed_div_rem, uint256_mul, uint256_sub, uint256_add, uint256_signed_nn
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import (
    get_block_number,
    get_block_timestamp,
)

// from openzeppelin.token.erc20.library import ERC20
from openzeppelin.token.erc20.IERC20 import IERC20
from openzeppelin.security.safemath.library import SafeUint256

const MULTIPLIER = 1000000000000000000;
const iMAX_TIME = 4 * 365 * 86400;
const WEEK = 7 * 86400;

struct LockedBalance {
    amount: Uint256,
    end: felt,
}

struct Point {
    bias: Uint256,
    slope: Uint256,
    ts: felt,
    blk: felt,
}

@event
func supply(prev_supply: felt, supply: felt) {
}

@event
func deposit(provider: felt, tokenId: felt, value: felt, lock_time: felt, deposit_type: felt, ts: felt) {
}

@event
func transfer(sender: felt, to: felt, tokenId: felt) {
}

@event
func withdraw_event(sender: felt, tokenId: felt, value: felt, block: felt) {
}

@event
func approval(owner: felt, approve: felt, tokenId: felt) {
}

@storage_var
func epoch_store() -> (epoch: felt) {
}

@storage_var
func supply_store() -> (supply: felt) {
}

@storage_var
func id_owner_store(tokenId: felt) -> (to: felt) {
}

@storage_var
func voter_store() -> (voter: felt) {
}

@storage_var
func voted_store(tokenId: felt) -> (voted: felt) {
}

@storage_var
func attachments_store(tokenId: felt) -> (attachment: felt) {
}

@storage_var
func id_approvals_store(tokenId: felt) -> (to: felt) {
}

@storage_var
func ownership_change_store(tokenId: felt) -> (block: felt) {
}

@storage_var
func owner_nft_count_store(to: felt) -> (count: felt) {
}

@storage_var
func token_to_owner_index(tokenId: felt) -> (count: felt) {
}

@storage_var
func num_checkpoint(address: felt) -> (src_rep_num: felt) {
}

@storage_var
func delegates_store(address: felt) -> (delegator: felt) {
}

@storage_var
func checkpoints_tokenIds(address, num, index) -> (tokenId: felt) {
}

@storage_var
func checkpoints_tokenIds_size(address, num) -> (tokenIds_size: felt) {
}

@storage_var
func checkpoints_timestamp(address, num) -> (timestamp: felt) {
}

@storage_var
func owner_to_NFT_list(to: felt, cur_count: felt) -> (tokenId: felt) {
}

@storage_var
func locked_amt_store(tokenId: felt) -> (amt: Uint256) {
}

@storage_var
func locked_end_store(tokenId: felt) -> (end: felt) {
}

@storage_var
func user_point_epoch_store(tokenId: felt) -> (user_epoch: felt) {
}

@storage_var
func user_point_history_bias_store(tokenId, epoch: felt) -> (last_point_bias: Uint256) {
}

@storage_var
func user_point_history_slope_store(tokenId, epoch: felt) -> (last_point_slope: Uint256) {
}

@storage_var
func user_point_history_ts_store(tokenId, epoch: felt) -> (ts: felt) {
}

@storage_var
func user_point_history_blk_store(tokenId, epoch: felt) -> (blk: felt) {
}

@storage_var
func point_history_bias_store(epoch: felt) -> (last_point_bias: Uint256) {
}

@storage_var
func point_history_slope_store(epoch: felt) -> (last_point_slope: Uint256) {
}

@storage_var
func point_history_ts_store(epoch: felt) -> (ts: felt) {
}

@storage_var
func point_history_blk_store(epoch: felt) -> (blk: felt) {
}

@storage_var
func slope_change_store(time: felt) -> (slope: Uint256) {
}

func uint256_to_address_felt(x: Uint256) -> (address: felt) {
    return (x.low + x.high * 2 ** 128,);
}

func _history_point_fill{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(t_i: felt, block_timestamp: felt,
    last_checkpoint: felt, l_p_slope: Uint256, l_p_bias: Uint256, l_p_ts: felt, l_p_blk: felt,
    i_l_p_ts: felt, i_l_p_blk: felt, block_slope: Uint256, _epoch: felt, index: felt) -> () {
    alloc_locals;

    if (index == 255)  {
        return ();
    }

    if (t_i == block_timestamp) {
        return ();
    }

    t_i = t_i + WEEK;

    let d_slope = Uint256(0, 0);

    let cmp_t_i = is_le(block_timestamp, t_i);

    if (cmp_t_i == 1) {
        t_i = block_timestamp;

        tempvar range_check_ptr = range_check_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar syscall_ptr = syscall_ptr;
    } else {
        let (sl) = slope_change_store.read(t_i);
        assert d_slope = sl;

        tempvar range_check_ptr = range_check_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar syscall_ptr = syscall_ptr;
    }

    let time_uint =  Uint256((t_i - last_checkpoint), 0);
    let (slope_mul_l, slope_mul_h) = uint256_mul(l_p_slope, time_uint);

    let (bias) = uint256_sub(l_p_bias, slope_mul_l);
    assert l_p_bias = bias;

    let (slope, carry) = uint256_add(l_p_slope, d_slope);
    assert l_p_slope = slope;

    let (slope_cmp) = uint256_signed_nn(l_p_slope);
    let (bias_cmp) = uint256_signed_nn(l_p_bias);

    if (slope_cmp == 0) {
        assert l_p_slope = Uint256(0, 0);
    }

    if (bias_cmp == 0) {
        assert l_p_bias = Uint256(0, 0);
    }

    last_checkpoint = t_i;
    l_p_ts = t_i;

    let (b_s_felt) = uint256_to_address_felt(block_slope);

    let bl = i_l_p_blk + (b_s_felt * (t_i - i_l_p_ts)) / MULTIPLIER;

    assert l_p_blk = bl;

    _epoch = _epoch + 1;

    point_history_slope_store.write(_epoch, l_p_slope);
    point_history_bias_store.write(_epoch, l_p_bias);
    point_history_ts_store.write(_epoch, l_p_ts);
    point_history_blk_store.write(_epoch, l_p_blk);

    return _history_point_fill(t_i, block_timestamp, last_checkpoint,
        l_p_slope, l_p_bias, l_p_ts, l_p_blk, i_l_p_ts, i_l_p_blk, block_slope, _epoch, index + 1);
}

@external
func _balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt) -> (count: felt) {

    let (curr_count) = owner_nft_count_store.read(owner);

    return (curr_count, );
}

@external
func _add_token_to_owner_list{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(to: felt, tokenId: felt) -> () {

    let (current_count) = _balance(to);

    owner_to_NFT_list.write(to, current_count, tokenId);
    token_to_owner_index.write(tokenId, current_count);

    return ();
}


@external
func _add_token_to{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(to: felt, tokenId: felt) -> () {

    id_owner_store.write(tokenId, to);

    _add_token_to_owner_list(to, tokenId);

    let (curr_count) = owner_nft_count_store.read(to);
    owner_nft_count_store.write(to, curr_count + 1);

    return ();
}

@external
func _mint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(to: felt, tokenId: felt) -> (sucess: felt) {

    _move_token_delegates(0, to, tokenId);

    _add_token_to(to, tokenId);
    transfer.emit(0, to, tokenId);

    return (1, );
}

@external
func _remove_token_from_owner_list{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(sender: felt, tokenId: felt) -> () {

    let (curr_count) = _balance(sender);
    curr_count = curr_count - 1;

    let (curr_index) = token_to_owner_index.read(tokenId);

    if (curr_count == curr_index) {
        owner_to_NFT_list.write(sender, curr_count, 0);
        token_to_owner_index.write(tokenId, 0);
    } else {
        let (last_tokenId) = owner_to_NFT_list.read(sender, curr_count);

        owner_to_NFT_list.write(sender, curr_index, last_tokenId);
        token_to_owner_index.write(last_tokenId, curr_index);

        owner_to_NFT_list.write(sender, curr_count, 0);
        token_to_owner_index.write(tokenId, 0);
    }

    return ();
}

@external
func _remove_token_from{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(sender: felt, tokenId: felt) -> () {

    id_owner_store.write(tokenId, 0);

    _remove_token_from_owner_list(sender, tokenId);

    let (curr_count) = owner_nft_count_store.read(sender);
    owner_nft_count_store.write(sender, curr_count - 1);

    return ();
}

@external
func approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(approved: felt, tokenId: felt) -> () {

    let (owner) = id_owner_store.read(tokenId);

    // @todo add assertions
    id_approvals_store.write(tokenId, approved);

    approval.emit(owner, approved, tokenId);
    return ();
}

@external
func _burn{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenId: felt) -> () {
    alloc_locals;
    let (owner) = id_owner_store.read(tokenId);

    // Approval
    approve(0, tokenId);
    let (dele) = delegates(owner);
    let (caller) = get_caller_address();
    _move_token_delegates(dele, 0, tokenId);

    _remove_token_from(caller, tokenId);
    transfer.emit(owner, 0, tokenId);

    return ();
}

@external
func _clear_approval{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt, tokenId: felt) -> () {
    alloc_locals;
    let (owner) = id_approvals_store.read(tokenId);

    if (owner != 0) {
        id_approvals_store.write(tokenId, 0);
        return ();
    } else {
        return ();
    }
}

@external
func _transfer_from{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_from: felt, to: felt, tokenId: felt, sender: felt) -> () {
    alloc_locals;

    _clear_approval(_from, tokenId);
    _remove_token_from(_from, tokenId);

    let (from_dele) = delegates(_from);
    let (to_dele) = delegates(to);
    let (block_number) = get_block_number();

    _move_token_delegates(from_dele, to_dele, tokenId);

    _add_token_to(to, tokenId);

    ownership_change_store.write(tokenId, block_number);
    transfer.emit(_from, to, tokenId);
    return ();
}

@external
func transfer_from{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_from: felt, to: felt, tokenId: felt) -> () {
    alloc_locals;

    let (caller) = get_caller_address();

    _transfer_from(_from, to, tokenId, caller);
    return ();
}


@external
func _checkpoint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenA: felt, old_locked: LockedBalance,
        new_locked: LockedBalance) -> (
    success: felt
) {
    alloc_locals;
    // let (_reserve0, _reserve1) = getReserves();
    let (caller) = get_caller_address();
    local u_old: Point* = new Point(Uint256(0, 0), Uint256(0, 0), 0, 0);
    local u_new: Point* = new Point(Uint256(0, 0), Uint256(0, 0), 0, 0);
    let old_dslope = Uint256(0, 0);
    let new_dslope = Uint256(0, 0);
    let (_epoch) = epoch_store.read();
    let (block_number) = get_block_number();
    let (block_timestamp) = get_block_timestamp();
    // local range_check_ptr=range_check_ptr;

    let cmp_old_time = is_le(old_locked.end, block_timestamp);
    let cmp_new_time = is_le(new_locked.end, block_timestamp);

    if (tokenA != 0) {
        if (cmp_old_time == 0) {
            let (cmp_old_amount) = uint256_lt(Uint256(0, 0), old_locked.amount);
            if (cmp_old_amount == 1) {
                let (div, rem) = uint256_signed_div_rem(old_locked.amount, Uint256(iMAX_TIME, 0));
                assert u_old.slope = div;
                let (low, high) = uint256_mul(u_old.slope, Uint256(old_locked.end - block_timestamp, 0));
                // check if high is 0 and no overflow
                assert u_old.bias = low;
                tempvar range_check_ptr=range_check_ptr;
                // tempvar syscall_ptr = syscall_ptr;
            } else {
                tempvar range_check_ptr=range_check_ptr;
                // tempvar syscall_ptr = syscall_ptr;
            }
            tempvar range_check_ptr=range_check_ptr;
            // tempvar syscall_ptr = syscall_ptr;
        } else {
            tempvar range_check_ptr=range_check_ptr;
            // tempvar syscall_ptr = syscall_ptr;
        }
        // tempvar range_check_ptr=range_check_ptr;

        if (cmp_new_time == 0) {
            let (cmp_new_amount) = uint256_lt(Uint256(0, 0), new_locked.amount);
            if (cmp_new_amount == 1) {
                let (div, rem) = uint256_signed_div_rem(new_locked.amount, Uint256(iMAX_TIME, 0));
                assert u_new.slope = div;
                let (low, high) = uint256_mul(u_new.slope, Uint256(new_locked.end - block_timestamp, 0));
                // check if high is 0 and no overflow
                assert u_new.bias = low;
                tempvar range_check_ptr=range_check_ptr;
                // tempvar syscall_ptr = syscall_ptr;
            } else {
                tempvar range_check_ptr=range_check_ptr;
                // tempvar syscall_ptr = syscall_ptr;
            }
        } else {
            tempvar range_check_ptr=range_check_ptr;
            // tempvar syscall_ptr = syscall_ptr;
        }
        tempvar range_check_ptr=range_check_ptr;
        // tempvar syscall_ptr = syscall_ptr;
    } else {
        tempvar range_check_ptr=range_check_ptr;
        // tempvar syscall_ptr = syscall_ptr;
    }

    let (o_s) = slope_change_store.read(old_locked.end);
    assert old_dslope = o_s;

    let cmp_new_end = is_not_zero(new_locked.end);

    tempvar syscall_ptr = syscall_ptr;

    if (cmp_new_end == 1) {
        if (new_locked.end == old_locked.end) {
            assert new_dslope = old_dslope;

            tempvar range_check_ptr = range_check_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar syscall_ptr = syscall_ptr;
        } else {
            let (n_s) = slope_change_store.read(new_locked.end);
            assert new_dslope = n_s;

            tempvar range_check_ptr = range_check_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar syscall_ptr = syscall_ptr;
        }

        tempvar range_check_ptr = range_check_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar syscall_ptr = syscall_ptr;
    } else {
        tempvar range_check_ptr = range_check_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar syscall_ptr = syscall_ptr;
    }

    let cmp_epoch = is_not_zero(_epoch);

    // local last_point: Point* = new Point(Uint256(0, 0), Uint256(0, 0), block_timestamp, block_number);

    local last_point_bias: Uint256;
    local last_point_slope: Uint256;
    local last_point_ts;
    local last_point_blk;

    if (cmp_epoch !=  0) {
        let (last_point_bias_epoch) = point_history_bias_store.read(_epoch);
        let (last_point_slope_epoch) = point_history_slope_store.read(_epoch);
        let (last_point_ts_epoch) = point_history_ts_store.read(_epoch);
        let (last_point_blk_epoch) = point_history_blk_store.read(_epoch);

        assert last_point_bias = last_point_bias_epoch;
        assert last_point_slope = last_point_slope_epoch;
        assert last_point_ts = last_point_ts_epoch;
        assert last_point_blk = last_point_blk_epoch;

        tempvar range_check_ptr = range_check_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar syscall_ptr = syscall_ptr;
    } else {
        tempvar range_check_ptr = range_check_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar syscall_ptr = syscall_ptr;
    }

    let last_checkpoint = last_point_ts;

    local initial_last_point_bias: Uint256 = last_point_bias;
    local initial_last_point_slope: Uint256 = last_point_slope;
    local initial_last_point_ts = last_point_ts;
    local initial_last_point_blk = last_point_blk;

    local block_slope: Uint256 = Uint256(0, 0);

    // let curr_time_cmp = is_le(old_locked.end, block_timestamp);

    let curr_time_cmp = block_timestamp - last_point_ts;

    if (curr_time_cmp != 0) {
        let blk_diff = block_number - last_point_blk;
        let (bl_s, bl_s_rem) = unsigned_div_rem(blk_diff, curr_time_cmp);
        let final_s = MULTIPLIER * bl_s;

        assert block_slope = Uint256(final_s, 0);

        tempvar range_check_ptr = range_check_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar syscall_ptr = syscall_ptr;
    } else {
        tempvar range_check_ptr = range_check_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar syscall_ptr = syscall_ptr;
    }

    let t_i = (last_checkpoint / WEEK) * WEEK;

    _history_point_fill(t_i, block_timestamp, last_checkpoint,
        last_point_slope, last_point_bias, last_point_ts, last_point_blk, initial_last_point_ts,
        initial_last_point_blk, block_slope, _epoch, 0);

    if (tokenA != 0) {
        if (cmp_old_time == 0) {
            let (o_s, carry) = uint256_add(old_dslope, u_old.slope);
            assert old_dslope = o_s;

            if (new_locked.end == old_locked.end) {
                let (diff) = uint256_sub(old_dslope, u_new.slope);
                assert old_dslope = diff;

                tempvar range_check_ptr = range_check_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
                tempvar syscall_ptr = syscall_ptr;
            } else {
                tempvar range_check_ptr = range_check_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
                tempvar syscall_ptr = syscall_ptr;
            }

            slope_change_store.write(old_locked.end, old_dslope);

            tempvar range_check_ptr = range_check_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar syscall_ptr = syscall_ptr;
        } else {
            tempvar range_check_ptr = range_check_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar syscall_ptr = syscall_ptr;
        }

        if (cmp_new_time == 0) {
            let cmp_new_old_time = is_le(old_locked.end, new_locked.end);

            if (cmp_new_old_time == 1) {
                let (diff) = uint256_sub(new_dslope, u_new.slope);

                assert new_dslope = diff;
                slope_change_store.write(new_locked.end, new_dslope);

                tempvar range_check_ptr = range_check_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
                tempvar syscall_ptr = syscall_ptr;
            } else {
                tempvar range_check_ptr = range_check_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
                tempvar syscall_ptr = syscall_ptr;
            }

            tempvar range_check_ptr = range_check_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar syscall_ptr = syscall_ptr;
        } else {
            tempvar range_check_ptr = range_check_ptr;
            tempvar pedersen_ptr = pedersen_ptr;
            tempvar syscall_ptr = syscall_ptr;
        }

        let (user_epoch) = user_point_epoch_store.read(tokenA);

        user_epoch = user_epoch + 1;

        user_point_epoch_store.write(tokenA, user_epoch);

        assert u_new.ts = block_timestamp;
        assert u_new.blk = block_number;

        user_point_history_bias_store.write(tokenA, user_epoch, u_new.bias);
        user_point_history_slope_store.write(tokenA, user_epoch, u_new.slope);
        user_point_history_ts_store.write(tokenA, user_epoch, u_new.ts);
        user_point_history_blk_store.write(tokenA, user_epoch, u_new.blk);

        tempvar range_check_ptr = range_check_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar syscall_ptr = syscall_ptr;
    } else {
        tempvar range_check_ptr = range_check_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar syscall_ptr = syscall_ptr;
    }

    // tempvar syscall_ptr = syscall_ptr;

    // Put slope based on time and give voting rights
    return (1, );
}

@external
func _supply_at_rec{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(l_p_bias: Uint256, l_p_slope: Uint256,
    l_p_ts: felt, l_p_blk: felt, t: felt, t_i: felt, index: felt) -> (
    bias: felt
) {

    if (index == 255) {
        let (l_p_bias_felt) = uint256_to_address_felt(l_p_bias);
        return (l_p_bias_felt, );
    }

    if (t_i == t) {
        let (l_p_bias_felt) = uint256_to_address_felt(l_p_bias);
        return (l_p_bias_felt, );
    }

    t_i = t_i + WEEK;
    let d_slope = Uint256(0, 0);

    let cmp_t = is_le(t, t_i);

    if (cmp_t == 1) {
        t_i = t;

        tempvar range_check_ptr = range_check_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar syscall_ptr = syscall_ptr;
    } else {
        let (s) = slope_change_store.read(t_i);

        assert d_slope = s;

        tempvar range_check_ptr = range_check_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar syscall_ptr = syscall_ptr;
    }

    let time_cmp_unit256 = Uint256(t_i - l_p_ts, 0);

    let (mul_l, mul_h) = uint256_mul(l_p_slope, time_cmp_unit256);

    let (slope_diff) = uint256_sub(l_p_slope, mul_l);

    assert l_p_bias = slope_diff;

    let (slope_add, carry) = uint256_add(l_p_slope, d_slope);

    assert l_p_slope = slope_add;
    assert l_p_ts = t_i;

    let (cmp_bias) = uint256_signed_nn(l_p_bias);

    if (cmp_bias == 0) {
        assert l_p_bias = Uint256(0, 0);

        tempvar range_check_ptr = range_check_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar syscall_ptr = syscall_ptr;
    } else {
        tempvar range_check_ptr = range_check_ptr;
        tempvar pedersen_ptr = pedersen_ptr;
        tempvar syscall_ptr = syscall_ptr;
    }

    return _supply_at_rec(l_p_bias, l_p_slope, l_p_ts, l_p_blk, t, t_i, index + 1);
}

@external
func _supply_at{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(l_p_bias: Uint256, l_p_slope: Uint256,
    l_p_ts: felt, l_p_blk: felt, t: felt) -> (
    supply: felt
) {
    let t_i = (l_p_ts / WEEK) * WEEK;
    let (supply) = _supply_at_rec(l_p_bias, l_p_slope, l_p_ts, l_p_blk, t, t_i, 0);

    return (supply, );
}


@external
func total_supply_at_T{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(t: felt) -> (
    supply: felt
) {
    let (_epoch) = epoch_store.read();
    let (last_point_bias) = point_history_bias_store.read(_epoch);
    let (last_point_slope) = point_history_slope_store.read(_epoch);
    let (last_point_ts) = point_history_ts_store.read(_epoch);
    let (last_point_blk) = point_history_blk_store.read(_epoch);

    let (supply) =  _supply_at(last_point_bias, last_point_slope, last_point_ts, last_point_blk, t);

    return (supply, );
}

@external
func _deposit_for{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenId: felt, value: felt,
    unlock_time: felt, l_b_amt: Uint256, l_b_end: felt, deposit_type: felt
) -> () {
    alloc_locals;
    let (supply_before) = supply_store.read();
    supply_store.write(supply_before + value);

    local old_locked: LockedBalance* = new LockedBalance(l_b_amt, l_b_end);
    let value_256 = Uint256(value, 0);

    let (amt_add, carry) = uint256_add(l_b_amt, value_256);
    assert l_b_amt = amt_add;

    let time_cmp = is_not_zero(unlock_time);

    if (time_cmp == 1) {
        assert l_b_end = unlock_time;
    }

    locked_amt_store.write(tokenId, l_b_amt);
    locked_end_store.write(tokenId, l_b_end);

    local new_locked: LockedBalance* = new LockedBalance(l_b_amt, l_b_end);

    _checkpoint(tokenId, old_locked[0], new_locked[0]);

    let (caller) = get_caller_address();
    let (block_timestamp) = get_block_timestamp();
    // @todo add validation. what is this validation here?

    deposit.emit(caller, tokenId, value, l_b_end, deposit_type, block_timestamp);
    supply.emit(supply_before, supply_before + value);

    return ();
}

@external
func deposit_for{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenId: felt, value: felt,
    ) -> () {
    let (l_amt) = locked_amt_store.read(tokenId);
    let (l_end) = locked_end_store.read(tokenId);

    // @todo assertion

    _deposit_for(tokenId, value, 0, l_amt, l_end, 0);

    return ();
}

@external
func withdraw{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenId: felt) -> () {
    alloc_locals;

    let (locked_end) = locked_end_store.read(tokenId);
    let (locked_amt) = locked_amt_store.read(tokenId);
    // @todo assert on lock. Very important

    let (locked_amt_felt) = uint256_to_address_felt(locked_amt);

    locked_end_store.write(tokenId, 0);
    locked_amt_store.write(tokenId, Uint256(0, 0));
    let (sup) = supply_store.read();
    let (caller) = get_caller_address();
    let (block_timestamp) = get_block_timestamp();

    supply_store.write(sup - locked_amt_felt);

    local old_locked: LockedBalance* = new LockedBalance(locked_amt, locked_end);
    local new_locked: LockedBalance* = new LockedBalance(Uint256(0, 0), 0);

    _checkpoint(tokenId, old_locked[0], new_locked[0]);

    // @todo what is this assertion?

    _burn(tokenId);


    supply.emit(sup, sup - locked_amt_felt);
    withdraw_event.emit(caller, tokenId, locked_amt_felt, block_timestamp);

    return ();
}

@external
func _balance_of_NFT{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenId: felt, t: felt,
    ) -> (balance: Uint256) {

    let (_epoch) = user_point_epoch_store.read(tokenId);

    if (_epoch == 0) {
        return (Uint256(0, 0), );
    } else {
        let (l_p_bias) = user_point_history_bias_store.read(tokenId, _epoch);
        let (l_p_slope) = user_point_history_slope_store.read(tokenId, _epoch);
        let (l_p_ts) = user_point_history_ts_store.read(tokenId, _epoch);

        let time_diff = t - l_p_ts;

        let (mul_l, mul_h) = uint256_mul(l_p_slope, Uint256(time_diff, 0));

        let (bias) = uint256_sub(l_p_bias, mul_l);

        let (cmp_bias) = uint256_signed_nn(bias);

        if (cmp_bias == 0) {
            user_point_history_bias_store.write(tokenId, _epoch, Uint256(0, 0));
        } else {
            user_point_history_bias_store.write(tokenId, _epoch, bias);
        }

        return (bias, );
    }
}

@external
func balance_of_NFT{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenId: felt
    ) -> (balance: Uint256) {

    let (block_timestamp) = get_block_timestamp();
    let (balance) = _balance_of_NFT(tokenId, block_timestamp);

    return (balance, );
}

@external
func balance_of_NFT_At{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenId: felt, t: felt,
    ) -> (balance: Uint256) {

    let (balance) = _balance_of_NFT(tokenId, t);

    return (balance, );
}

@external
func _balance_of_At_NFT{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenId: felt, t: felt,
    ) -> (balance: Uint256) {

    // @todo where is this used?

    // let (_epoch) = user_point_epoch_store.read(tokenId);

    // if (_epoch == 0) {
    //     return (Uint256(0, 0), );
    // } else {
    //     let (l_p_bias) = user_point_history_bias_store.read(tokenId, _epoch);
    //     let (l_p_slope) = user_point_history_slope_store.read(tokenId, _epoch);
    //     let (l_p_ts) = user_point_history_ts_store.read(tokenId, _epoch);

    //     let time_diff = t - l_p_ts;

    //     let (mul_l, mul_h) = uint256_mul(l_p_slope, Uint256(time_diff, 0));

    //     let (bias) = uint256_sub(l_p_bias, mul_l);

    //     let (cmp_bias) = uint256_signed_nn(bias);

    //     if (cmp_bias == 0) {
    //         user_point_history_bias_store.write(tokenId, _epoch, Uint256(0, 0));
    //     } else {
    //         user_point_history_bias_store.write(tokenId, _epoch, bias);
    //     }

    //     return (bias, );
    // }

    return (Uint256(0, 0), );
}

@external
func balance_of_At_NFT{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenId: felt, block: felt,
    ) -> (balance: Uint256) {

    let (balance) = _balance_of_At_NFT(tokenId, block);

    return (balance, );
}

@external
func set_voter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(voter: felt
    ) -> () {

    voter_store.write(voter);

    return ();
}

@external
func voting{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenId: felt
    ) -> () {

    voted_store.write(tokenId, 1);

    return ();
}

@external
func abstain{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenId: felt
    ) -> () {

    voted_store.write(tokenId, 0);

    return ();
}

@external
func attach{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenId: felt
    ) -> () {

    let (attachment) = attachments_store.read(tokenId);

    attachments_store.write(tokenId, attachment + 1);

    return ();
}

@external
func detach{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenId: felt
    ) -> () {

    let (attachment) = attachments_store.read(tokenId);

    attachments_store.write(tokenId, attachment - 1);

    return ();
}

@external
func merge{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(sender: felt, to: felt
    ) -> () {

    // @todo is this required and if so where?

    return ();
}

@external
func increase_amount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenId: felt, value: felt,
    ) -> () {
    let (l_amt) = locked_amt_store.read(tokenId);
    let (l_end) = locked_end_store.read(tokenId);

    // @todo assertion

    _deposit_for(tokenId, value, 0, l_amt, l_end, 2);

    return ();
}

@external
func increase_unlock_time{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenId: felt, lock_duration: felt,
    ) -> () {
    let (l_amt) = locked_amt_store.read(tokenId);
    let (l_end) = locked_end_store.read(tokenId);
    let (block_timestamp) = get_block_timestamp();

    let unlock_time = (lock_duration + block_timestamp) / WEEK * WEEK;

    // @todo assertion

    _deposit_for(tokenId, 0, unlock_time, l_amt, l_end, 3);

    return ();
}

@external
func delegates{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(delegator: felt) -> (address: felt) {
    let (current) = delegates_store.read(delegator);

    if (current == 0) {
        return (delegator, );
    } else {
        return (current, );
    }
}

@external
func _get_checkpoints_tokenIds_rec{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenIds_len: felt,
        tokenIds: felt*, account: felt, num: felt, index: felt
    ) -> (tokenIds_len: felt, tokenIds: felt*) {

    if (index == tokenIds_len) {
        return (tokenIds_len, tokenIds);
    }

    let (tokenId) = checkpoints_tokenIds.read(account, num, index);

    assert tokenIds[index] = tokenId;

    return _get_checkpoints_tokenIds_rec(tokenIds_len, tokenIds, account, num, index + 1);
}

@external
func _get_votes_rec{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenIds_len: felt,
    tokenIds: felt*, b_t: felt, votes: felt, index: felt
) -> (votes: felt) {
    alloc_locals;

    if (index == tokenIds_len) {
        return (votes, );
    }

    let t = tokenIds[index];

    let (balance) = _balance_of_NFT(t, b_t);

    let (balance_felt) = uint256_to_address_felt(balance);

    votes = votes + balance_felt;

    return _get_votes_rec(tokenIds_len, tokenIds, b_t, votes, index + 1);
}

@external
func get_votes{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(account: felt) -> (votes: felt) {
    alloc_locals;
    let (n_checkpoints) = num_checkpoint.read(account);

    let (c_tokenIds_size) = checkpoints_tokenIds_size.read(account, n_checkpoints);

    let _tokenIds: felt* = alloc();

    let (tokenIds_len, tokenIds) = _get_checkpoints_tokenIds_rec(c_tokenIds_size, _tokenIds, account, n_checkpoints, 0);

    assert _tokenIds = tokenIds;

    let votes_num = 0;
    let (block_timestamp) = get_block_timestamp();

    let (v) = _get_votes_rec(tokenIds_len, tokenIds, block_timestamp, votes_num, 0);

    votes_num = v;

    return (votes_num,);
}

@external
func _get_past_votes_index_rec{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(upper: felt,
    lower: felt, t: felt, account: felt
) -> (lower: felt) {
    alloc_locals;
    let cmp_u_l = is_le(lower, upper);

    if (cmp_u_l == 0) {
        return (lower, );
    }

    let center = upper - (upper - lower) / 2;
    let (c_t) = checkpoints_timestamp.read(account, center);

    let cmp_c_t = is_le(c_t, t);

    if (c_t == t) {
        return (center, );
    }

    if (cmp_c_t == 1) {
        assert lower = center;
    } else {
        assert upper = center - 1;
    }

    return _get_past_votes_index_rec(upper, lower, t, account);
}

@external
func get_past_votes_index{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(account: felt, t: felt) -> (vote_index: felt) {
    alloc_locals;
    let (n_checkpoints) = num_checkpoint.read(account);

    if (n_checkpoints == 0) {
        return (0,);
    }

    let (c_t) = checkpoints_timestamp.read(account, n_checkpoints - 1);

    let cmp_c_t = is_le(c_t, t);

    if (cmp_c_t == 1) {
        return (n_checkpoints - 1,);
    }

    let (c_t_0) = checkpoints_timestamp.read(account,0);

    let cmp_c_t_0 = is_le(t, c_t_0);

    if (cmp_c_t_0 == 1) {
        return (0,);
    }



    let lower = 0;
    let upper = n_checkpoints - 1;
    let (l) = _get_past_votes_index_rec(upper, lower, t, account);

    return (l, );
}

@external
func get_past_votes{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(account: felt, t: felt) -> (vote: felt) {
    alloc_locals;

    let (i) = get_past_votes_index(account, t);

    let (c_tokenIds_size) = checkpoints_tokenIds_size.read(account, i);

    let _tokenIds: felt* = alloc();

    let (tokenIds_len, tokenIds) = _get_checkpoints_tokenIds_rec(c_tokenIds_size, _tokenIds, account, i, 0);

    assert _tokenIds = tokenIds;

    let votes_num = 0;

    let (v) = _get_votes_rec(tokenIds_len, tokenIds, t, votes_num, 0);

    return (v, );
}


@external
func _move_token_delegates_rec{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(src_len: felt,
    src: felt*, rep: felt, rep_num: felt, index: felt
    ) -> (tokenIds_len: felt, tokenIds: felt*) {

    if (index == src_len) {
        return (src_len, src);
    }

    let (token) = checkpoints_tokenIds.read(rep, rep_num, index);

    assert src[index] = token;

    return _move_token_delegates_rec(src_len, src, rep, rep_num, index+1);
}

@external
func _fill_token_rec{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(src_len: felt,
    src: felt*, src_rep_old_len: felt, src_rep_old: felt*, tokenId: felt, index: felt
    ) -> (tokenIds_len: felt, tokenIds: felt*) {

    if (index == src_rep_old_len) {
        return (src_len, src);
    }

    let t_id = src_rep_old[index];

    if (t_id != tokenId) {
        assert src_len = src_len + 1;
        assert src[src_len] = t_id;
    }

    return _fill_token_rec(src_len, src, src_rep_old_len, src_rep_old, tokenId, index+1);
}

@external
func _find_what_checkpoint_to_write{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(account: felt
    ) -> (checkpoint: felt) {

    let (block_timestamp) = get_block_timestamp();
    let (checkpoints_num) = num_checkpoint.read(account);
    let (checkpoint_timestamp) = checkpoints_timestamp.read(account, checkpoints_num - 1);

    let cmp_checkpoints = is_not_zero(checkpoints_num);

    if (cmp_checkpoints == 1) {

        if (checkpoint_timestamp == block_timestamp) {
            return (checkpoints_num - 1, );
        } else {
            return (checkpoints_num, );
        }
    } else {
        return (checkpoints_num, );
    }
}


@external
func _move_token_delegates{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(src_rep: felt, dst_rep: felt, tokenId: felt
    ) -> () {
    alloc_locals;
    let cmp_tokenId = is_not_zero(tokenId);

    if (src_rep != dst_rep) {

        if (cmp_tokenId == 1) {
            // Logic for both cases

            let cmp_src_rep = is_not_zero(src_rep);

            if (cmp_src_rep == 1) {
                let (src_rep_num) = num_checkpoint.read(src_rep);

                let cmp_src_rep_num = is_not_zero(src_rep_num);
                local src_rep_old: felt*;
                local src_rep_old_len: felt;

                if (cmp_src_rep_num == 1) {
                    // get token Ids

                    let (src_rep_old_tokens: felt*) = alloc();

                    let (src_rep_old_size) = checkpoints_tokenIds_size.read(src_rep, src_rep_num - 1);
                    assert src_rep_old_len = src_rep_old_size;

                    let (src_rep_tokenIds_len, src_rep_tokenIds) = _move_token_delegates_rec(src_rep_old_size, src_rep_old_tokens, src_rep, src_rep_num - 1, 0);

                    assert src_rep_old = src_rep_tokenIds;
                } else {
                    let (src_rep_old_tokens: felt*) = alloc();

                    let (src_rep_old_size) = checkpoints_tokenIds_size.read(src_rep, 0);
                    assert src_rep_old_len = src_rep_old_size;

                    let (src_rep_tokenIds_len, src_rep_tokenIds) = _move_token_delegates_rec(src_rep_old_size, src_rep_old_tokens, src_rep, 0, 0);

                    assert src_rep_old = src_rep_tokenIds;
                }
                let (next_ser_rep_num) = _find_what_checkpoint_to_write(src_rep);

                let (src_rep_new_tokens: felt*) = alloc();
                let (src_rep_new_size) = checkpoints_tokenIds_size.read(src_rep, next_ser_rep_num);
                let (src_rep_new_len, src_rep_new) = _move_token_delegates_rec(src_rep_new_size, src_rep_new_tokens, src_rep, next_ser_rep_num, 0);

                _fill_token_rec(src_rep_new_len, src_rep_new, src_rep_old_len, src_rep_old, tokenId, 0);

                num_checkpoint.write(src_rep, src_rep_num + 1);

                tempvar range_check_ptr = range_check_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
                tempvar syscall_ptr = syscall_ptr;
            } else {
                tempvar range_check_ptr = range_check_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
                tempvar syscall_ptr = syscall_ptr;
            }

            let cmp_dst_rep = is_not_zero(dst_rep);

            if (cmp_dst_rep == 1) {
                let (dst_rep_num) = num_checkpoint.read(dst_rep);

                let cmp_dst_rep_num = is_not_zero(dst_rep_num);
                local dst_rep_old: felt*;
                local dst_rep_old_len: felt;

                if (cmp_dst_rep_num == 1) {
                    // get token Ids

                    let (dst_rep_old_tokens: felt*) = alloc();

                    let (dst_rep_old_size) = checkpoints_tokenIds_size.read(dst_rep, dst_rep_num - 1);
                    assert dst_rep_old_len = dst_rep_old_size;

                    let (dst_rep_tokenIds_len, dst_rep_tokenIds) = _move_token_delegates_rec(dst_rep_old_size, dst_rep_old_tokens, dst_rep, dst_rep_num - 1, 0);

                    assert dst_rep_old = dst_rep_tokenIds;
                } else {
                    let (dst_rep_old_tokens: felt*) = alloc();

                    let (dst_rep_old_size) = checkpoints_tokenIds_size.read(dst_rep, 0);
                    assert dst_rep_old_len = dst_rep_old_size;

                    let (dst_rep_tokenIds_len, dst_rep_tokenIds) = _move_token_delegates_rec(dst_rep_old_size, dst_rep_old_tokens, dst_rep, 0, 0);

                    assert dst_rep_old = dst_rep_tokenIds;
                }
                let (next_dst_rep_num) = _find_what_checkpoint_to_write(dst_rep);

                let (dst_rep_new_tokens: felt*) = alloc();
                let (dst_rep_new_size) = checkpoints_tokenIds_size.read(dst_rep, next_dst_rep_num);
                let (dst_rep_new_len, dst_rep_new) = _move_token_delegates_rec(dst_rep_new_size, dst_rep_new_tokens, dst_rep, next_dst_rep_num, 0);

                _fill_token_rec(dst_rep_new_len, dst_rep_new, dst_rep_old_len, dst_rep_old, tokenId, 0);

                num_checkpoint.write(dst_rep, dst_rep_num + 1);

                tempvar range_check_ptr = range_check_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
                tempvar syscall_ptr = syscall_ptr;
            } else {
                tempvar range_check_ptr = range_check_ptr;
                tempvar pedersen_ptr = pedersen_ptr;
                tempvar syscall_ptr = syscall_ptr;
            }
        } else {
            return ();
        }

        return ();
    } else {
        return ();
    }
}

@external
func deposit_vote{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenA: felt, to: felt,
        time: felt, amount: Uint256) -> (
    success: felt
) {
    alloc_locals;
    // let (_reserve0, _reserve1) = getReserves();
    let (caller) = get_caller_address();
    // let (tokenA) = tokenA_store.read();
    // let (tokenB) = tokenB_store.read();
    // Do I have to initialize with ERC20 function
    // let ERC20balance0 = ERC20.initializer('tokenA', tokenA, 10**8)
    // let (balance0) = ERC20.balance_of(caller)
    // token A contract
    let (success) = IERC20.transfer(tokenA, to, amount);

    // Put slope based on time and give voting rights
    return (success, );

}
