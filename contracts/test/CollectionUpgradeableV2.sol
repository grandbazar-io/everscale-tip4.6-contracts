pragma ton-solidity ^0.58.1;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "../Collection/CollectionUpgradeableBase.sol";

contract CollectionUpgradeableV2 is CollectionUpgradeableBase {
    function mint(
        string json,
        string licenseURI,
        string licenseName,
        mapping(address => uint8) royalty
    ) external virtual returns (address nftAddr) {
        require(msg.value >= _totalCreationPrice(), BaseErrors.not_enough_value);
        /// reserve original_balance + _mintingFee
        tvm.rawReserve(_mintingFee, 4);

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

        // TODO: upgrade event
        /// @dev Logic for setting new storage data coming from collection
        TvmSlice newDataSlice = newStorageData.toSlice();
        if (!newDataSlice.empty()) {}

        tvm.rawReserve(remainOnCollection, 2);

        // TODO: upgrade event
        // TODO: collection created event
        if (_collectionVersion == oldVersion) {
            _deployIndexBasis();
            // emit NftCreated(_id, _owner, _manager, _collection);
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
        TvmCell newStorageData = abi.encode(sender);
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

    // TODO: interfaces
    function supportsInterface(bytes4 interfaceID) external view responsible override returns (bool) {
        return { value: 0, flag: 64, bounce: false } _supportedInterfaces[interfaceID];
    }

    function testAddress(uint256 id) public view returns (address) {
        TvmCell data = tvm.buildDataInit({ contr: NftPlatform, varInit: { _id: id }, pubkey: 0 });
        uint256 dataHash = tvm.hash(data);
        uint16 dataDepth = data.depth();
        uint256 codeHash = tvm.stateInitHash(
            tvm.hash(_buildPlatformCode(address(this))),
            dataHash,
            _nftPlatformCode.depth(),
            dataDepth
        );
        return address.makeAddrStd(address(this).wid, codeHash);
    }
}
