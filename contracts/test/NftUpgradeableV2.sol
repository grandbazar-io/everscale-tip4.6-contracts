pragma ton-solidity ^0.58.1;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "../Nft/NftUpgradeableBase.sol";

contract NftUpgradeableV2 is NftUpgradeableBase {
    address _testAddress;

    function getTestAddress() external view responsible returns (address) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } _testAddress;
    }

    function acceptUpgrade(
        TvmCell newCode,
        TvmCell newData,
        uint32 newVersion,
        uint128 remainOnNft,
        address sendGasTo
    ) external override onlyCollection {
        if (_version == newVersion) {
            tvm.rawReserve(remainOnNft, 2);
            sendGasTo.transfer({ value: 0, flag: MsgFlags.ALL_NOT_RESERVED + MsgFlags.IGNORE_ERRORS, bounce: false });
        } else {
            TvmCell data;
            TvmCell newStorageData = abi.encode(_manager, _testAddress);
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
        if (!upgradeData.toSlice().empty()) {
            // V2 changes
            _testAddress = abi.decode(upgradeData, (address));
            _manager = abi.decode(newStorageData, (address));
        } else {
            _testAddress = abi.decode(newStorageData, (address));
        }

        tvm.rawReserve(remainOnNft, 2);

        if (_version == oldVersion) {
            _manager = _owner;
            _deployIndex();
            emit NftCreated(_id, _owner, _manager, _collection);
        }

        if (sendGasTo.value != 0 && sendGasTo != address(this)) {
            sendGasTo.transfer({ value: 0, flag: MsgFlags.ALL_NOT_RESERVED + MsgFlags.IGNORE_ERRORS, bounce: false });
        }
    }
}
