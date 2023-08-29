pragma ton-solidity ^0.58.1;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "../libraries/MsgFlags.sol";

contract CollectionPlatform {
    uint8 constant value_is_empty = 101;
    uint8 constant sender_is_not_collections_root = 102;
    uint8 constant value_is_less_than_required = 104;

    uint256 static _id;

    constructor(TvmCell collectionCode, TvmCell data) public {
        optional(TvmCell) optSalt = tvm.codeSalt(tvm.code());
        require(optSalt.hasValue(), value_is_empty);
        address collectionsRoot = optSalt.get().toSlice().decode(address);
        require(msg.sender == collectionsRoot, sender_is_not_collections_root);

        initialize(collectionCode, data);
    }

    function initialize(TvmCell collectionCode, TvmCell data) private {
        tvm.setcode(collectionCode);
        tvm.setCurrentCode(collectionCode);

        onCodeUpgrade(data);
    }

    function onCodeUpgrade(TvmCell data) private {}
}
