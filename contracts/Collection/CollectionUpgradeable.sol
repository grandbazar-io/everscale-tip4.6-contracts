pragma ton-solidity ^0.58.1;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./CollectionUpgradeableBase.sol";

contract CollectionUpgradeable is CollectionUpgradeableBase {
    function mint(
        string json,
        string licenseURI,
        string licenseName,
        mapping(address => uint8) royalty
    ) external virtual returns (address nftAddr) {
        require(msg.value >= _totalCreationPrice(), BaseErrors.not_enough_value);
        /// reserve original_balance + _mintingFee
        tvm.rawReserve(_reserve(), 0);
        _withdrawalAddress.transfer(_mintingFee, false, MsgFlags.SENDER_PAYS_FEES + MsgFlags.IGNORE_ERRORS);

        nftAddr = _deployNft(msg.sender, json, licenseURI, licenseName, royalty);
    }

    function acceptUpgrade(
        TvmCell newCode,
        TvmCell newData,
        uint32 newVersion,
        uint128 remainOnCollection,
        address sendGasTo
    ) external virtual override onlyCollectionsRoot {
        if (_collectionVersion == newVersion) {
            tvm.rawReserve(remainOnCollection, 2);
            sendGasTo.transfer({ value: 0, flag: MsgFlags.ALL_NOT_RESERVED + MsgFlags.IGNORE_ERRORS, bounce: false });
        } else {
            TvmCell newStorageData;
            uint32 currentVersion = _collectionVersion;

            TvmCell data = abi.encode(
                _id,
                _codeNft,
                _codeIndex,
                _codeIndexBasis,
                _nftPlatformCode,
                _upgradedNftData,
                newStorageData,
                newData,
                _totalSupply,
                _indexDeployValue,
                _indexDestroyValue,
                _deployIndexBasisValue,
                _remainOnNft,
                remainOnCollection,
                _methodsCallsFee,
                _nftBurnFee,
                _minimalGasAmount,
                _mintingFee,
                _withdrawalAddress,
                _owner,
                _author,
                _isProtected,
                sendGasTo,
                _lastTokenId,
                _json,
                _nftVersion,
                currentVersion,
                newVersion
            );
            tvm.setcode(newCode);
            tvm.setCurrentCode(newCode);
            onCodeUpgrade(data);
        }
    }

    function onCodeUpgrade(TvmCell data) private {
        tvm.resetStorage();
        optional(TvmCell) optSalt = tvm.codeSalt(tvm.code());
        _collectionsRoot = optSalt.get().toSlice().decode(address);

        uint128 remainOnCollection;
        TvmCell newStorageData;
        TvmCell upgradeData;
        address sendGasTo;
        uint32 oldVersion;

        (
            _id,
            _codeNft,
            _codeIndex,
            _codeIndexBasis,
            _nftPlatformCode,
            _upgradedNftData,
            newStorageData,
            upgradeData,
            _totalSupply,
            _indexDeployValue,
            _indexDestroyValue,
            _deployIndexBasisValue,
            _remainOnNft,
            remainOnCollection,
            _methodsCallsFee,
            _nftBurnFee,
            _minimalGasAmount,
            _mintingFee,
            _withdrawalAddress,
            _owner,
            _author,
            _isProtected,
            sendGasTo,
            _lastTokenId,
            _json,
            _nftVersion,
            oldVersion,
            _collectionVersion
        ) = abi.decode(
            data,
            (
                uint256,
                TvmCell,
                TvmCell,
                TvmCell,
                TvmCell,
                TvmCell,
                TvmCell,
                TvmCell,
                uint128,
                uint128,
                uint128,
                uint128,
                uint128,
                uint128,
                uint128,
                uint128,
                uint128,
                uint128,
                address,
                address,
                address,
                bool,
                address,
                uint256,
                string,
                uint32,
                uint32,
                uint32
            )
        );

        /// @dev Logic for setting new storage data coming from collection
        TvmSlice newDataSlice = newStorageData.toSlice();
        if (!newDataSlice.empty()) {}

        tvm.rawReserve(remainOnCollection, 2);

        if (_collectionVersion == oldVersion) {
            _deployIndexBasis();
            emit CollectionCreated(_id, _collectionsRoot, _author, _json, _isProtected);
        } else {
            emit CollectionUpgraded(oldVersion, _collectionVersion);
        }

        if (sendGasTo.value != 0 && sendGasTo != address(this)) {
            sendGasTo.transfer({ value: 0, flag: MsgFlags.ALL_NOT_RESERVED + MsgFlags.IGNORE_ERRORS, bounce: false });
        }
    }

    function _deployNft(
        address sender,
        string json,
        string licenseURI,
        string licenseName,
        mapping(address => uint8) royalty
    ) internal virtual returns (address) {
        uint256 id = _lastTokenId;
        _totalSupply++;
        _lastTokenId++;

        TvmCell codeNft = _buildPlatformCode(address(this));
        TvmCell stateNft = _buildPlatformState(codeNft, id);
        TvmCell data;
        /// @dev Cell that will be filled with new properties from mint in future.
        /// We should add any new property that come from mint method to this cell
        TvmCell newStorageData;
        /// @dev Cell that will be filled with new properties from upgrade in future.
        /// Collection should add any new property that have to be added to NFT after upgrade to this cell
        TvmCell upgradeData;

        data = abi.encode(
            id,
            _codeIndex,
            newStorageData,
            upgradeData,
            _indexDeployValue,
            _indexDestroyValue,
            _remainOnNft,
            /// Old and new version are equal during mint
            _nftVersion,
            _nftVersion,
            sender,
            sender,
            json,
            licenseURI,
            licenseName,
            royalty
        );

        address nftAddress = new NftPlatform{ stateInit: stateNft, value: 0, flag: 128 }(
            _buildNftCode(address(this), _codeNft),
            data,
            _remainOnNft
        );

        emit NftCreated(id, nftAddress, sender, sender, sender);

        return nftAddress;
    }
}
