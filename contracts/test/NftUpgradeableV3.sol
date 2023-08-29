pragma ton-solidity ^0.58.1;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "../Nft/NftUpgradeableBase.sol";

contract NftUpgradeableV3 is NftUpgradeableBase {
    address _testAddress;
    string _geoData;

    function getTestAddress() external view responsible returns (address) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } _testAddress;
    }

    function getGeoData() external view responsible returns (string) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } _geoData;
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
            TvmCell newStorageData = abi.encode(_manager, _testAddress, _geoData);

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
            if (oldVersion == 0) {
                (_testAddress, _geoData) = abi.decode(upgradeData, (address, string));
                _manager = abi.decode(newStorageData, (address));
            } else {
                (_manager, _testAddress) = abi.decode(newStorageData, (address, address));
                (, _geoData) = abi.decode(upgradeData, (address, string));
            }
        } else {
            (_testAddress, _geoData) = abi.decode(newStorageData, (address, string));
        }

        tvm.rawReserve(remainOnNft, 2);

        if (_version == 0) {
            _manager = _owner;
            _deployIndex();
            emit NftCreated(_id, _owner, _manager, _collection);
        }

        if (sendGasTo.value != 0 && sendGasTo != address(this)) {
            sendGasTo.transfer({ value: 0, flag: MsgFlags.ALL_NOT_RESERVED + MsgFlags.IGNORE_ERRORS, bounce: false });
        }
    }
}
