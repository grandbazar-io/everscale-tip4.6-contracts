pragma ton-solidity ^0.58.1;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./NftUpgradeableBase.sol";

contract NftUpgradeable is NftUpgradeableBase {
    function acceptUpgrade(
        TvmCell newCode,
        TvmCell newData,
        uint32 newVersion,
        uint128 remainOnNft,
        address sendGasTo
    ) external virtual override onlyCollection {
        if (_version == newVersion) {
            tvm.rawReserve(remainOnNft, 2);
            sendGasTo.transfer({ value: 0, flag: MsgFlags.ALL_NOT_RESERVED + MsgFlags.IGNORE_ERRORS, bounce: false });
        } else {
            TvmCell data;
            TvmCell newStorageData = abi.encode(_manager);
            data = abi.encode(
                _id,
                _codeIndex,
                newStorageData,
                newData,
                _indexDeployValue,
                _indexDestroyValue,
                remainOnNft,
                _version,
                newVersion,
                sendGasTo,
                _owner,
                _json,
                _licenseURI,
                _licenseName,
                _royalty
            );

            tvm.setcode(newCode);
            tvm.setCurrentCode(newCode);
            onCodeUpgrade(data);
        }
    }

    function onCodeUpgrade(TvmCell data) private {
        tvm.resetStorage();
        optional(TvmCell) optSalt = tvm.codeSalt(tvm.code());
        TvmSlice slice;
        slice = optSalt.get().toSlice();
        _collection = optSalt.get().toSlice().decode(address);
        uint32 oldVersion;

        uint128 remainOnNft;
        TvmCell newStorageData;
        TvmCell upgradeData;
        address sendGasTo;

        (
            _id,
            _codeIndex,
            newStorageData,
            upgradeData,
            _indexDeployValue,
            _indexDestroyValue,
            remainOnNft,
            oldVersion,
            _version,
            sendGasTo,
            _owner,
            _json,
            _licenseURI,
            _licenseName,
            _royalty
        ) = abi.decode(
            data,
            (
                uint256,
                TvmCell,
                TvmCell,
                TvmCell,
                uint128,
                uint128,
                uint128,
                uint32,
                uint32,
                address,
                address,
                string,
                string,
                string,
                mapping(address => uint8)
            )
        );

        /// @dev Logic for setting new storage data coming from collection
        TvmSlice newDataSlice = newStorageData.toSlice();
        if (!newDataSlice.empty()) {}

        tvm.rawReserve(remainOnNft, 2);
        _manager = _owner;

        if (_version == oldVersion) {
            _deployIndex();
            emit NftCreated(_id, _owner, _manager, _collection);
        } else {
            emit NftUpgraded(oldVersion, _version);
        }

        if (sendGasTo.value != 0 && sendGasTo != address(this)) {
            sendGasTo.transfer({ value: 0, flag: MsgFlags.ALL_NOT_RESERVED + MsgFlags.IGNORE_ERRORS, bounce: false });
        }
    }
}
