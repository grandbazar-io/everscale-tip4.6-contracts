pragma ton-solidity ^0.58.1;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "../libraries/MsgFlags.sol";

contract NftPlatform {
    uint8 constant value_is_empty = 101;
    uint8 constant sender_is_not_collection = 102;
    uint8 constant value_is_less_than_required = 104;

    uint256 static _id;

    constructor(TvmCell nftCode, TvmCell data, uint128 remainOnNft) public {
        optional(TvmCell) optSalt = tvm.codeSalt(tvm.code());
        require(optSalt.hasValue(), value_is_empty);
        address collection = optSalt.get().toSlice().decode(address);
        require(msg.sender == collection, sender_is_not_collection);
        require(remainOnNft != 0, value_is_empty);
        require(msg.value > remainOnNft, value_is_less_than_required);

        initialize(nftCode, data);
    }

    function initialize(TvmCell nftCode, TvmCell data) private {
        tvm.setcode(nftCode);
        tvm.setCurrentCode(nftCode);

        onCodeUpgrade(data);
    }

    function onCodeUpgrade(TvmCell data) private {}
}
