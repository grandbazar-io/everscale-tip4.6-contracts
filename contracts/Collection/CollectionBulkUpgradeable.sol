pragma ton-solidity ^0.58.1;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./CollectionUpgradeableBase.sol";
import "../Nft/NftBulkUpgradeable.sol";

import "./interfaces/ICollectionBulk.sol";

contract CollectionBulkUpgradeable is CollectionUpgradeableBase, ICollectionBulk {
    uint8 constant amount_is_zero = 230;
    uint128 _editionsSupply;
    /// @notice Value that will be sent to proxy contract
    uint128 _sendToProxyValue;

    /// @param amount Amount of NFTs to mint
    /// @param royalty mapping address => percent
    /// @param json Nft json string
    /// @param proxy Address of proxy contract for calling OnNftCreated callback from NFT
    /// @param payload Custom payload for calling OnNftCreated callback from NFT
    /// @notice If user wants to put all NFT on sale he has to send _totalCreationPrice() * amount +
    /// + offer deployment price * amount + _methodsCallsFee * 4.
    /// @notice Offer deployment price should be requested from SellRoot contract
    /// @notice Payload should be requested from from SellRoot. For example, sell payload should contain (uint128 price)
    function bulkMint(
        uint32 amount,
        mapping(address => uint8) royalty,
        string json,
        address proxy,
        TvmCell payload,
        string licenseURI,
        string licenseName
    ) external virtual internalMsg {
        require(amount > 0, amount_is_zero);
        /// @notice Values should contain deployment price as well! Without it putting on sell will fail
        require(msg.value >= _totalCreationPrice() * amount, BaseErrors.not_enough_value);
        tvm.rawReserve(_reserve(), 0);
        _withdrawalAddress.transfer(_mintingFee * amount, false, MsgFlags.SENDER_PAYS_FEES + MsgFlags.IGNORE_ERRORS);

        ITIP4_1NFT.CallbackParams callbackParams;
        TvmSlice payloadSlice = payload.toSlice();

        if (!payloadSlice.empty() && proxy != address(0)) {
            /// @dev Value that will be sent from NFT to proxy
            uint128 processingValue = msg.value / amount + (2 * _methodsCallsFee) - _totalCreationPrice();
            /// @dev Callback params will be sent from NFT to proxy
            callbackParams = ITIP4_1NFT.CallbackParams(processingValue, payload);

            // Send some evers to proxy contract to pay for cancellation and management returning, etc
            proxy.transfer({ value: _sendToProxyValue * amount, bounce: true, flag: 1 });
        }

        _editionsSupply++;
        uint128 editionId = _editionsSupply;

        _invokeMint(msg.sender, royalty, json, callbackParams, proxy, licenseURI, licenseName, editionId, amount, 0);
    }

    function _invokeMint(
        address owner,
        mapping(address => uint8) royalty,
        string json,
        ITIP4_1NFT.CallbackParams callbackParams,
        address sellProxy,
        string licenseURI,
        string licenseName,
        uint128 editionId,
        uint32 amount,
        uint32 currentIteration
    ) internal pure virtual {
        if (currentIteration < amount) {
            CollectionBulkUpgradeable(address(this)).mint{ value: 0, flag: 128 }(
                owner,
                royalty,
                json,
                callbackParams,
                sellProxy,
                licenseURI,
                licenseName,
                editionId,
                amount,
                currentIteration
            );
        } else {
            owner.transfer({ value: 0, flag: 128 + 2, bounce: false });
        }
    }

    function mint(
        address owner,
        mapping(address => uint8) royalty,
        string json,
        ITIP4_1NFT.CallbackParams callbackParams,
        address sellProxy,
        string licenseURI,
        string licenseName,
        uint128 editionId,
        uint32 amount,
        uint32 currentIteration
    ) external virtual internalMsg {
        require(msg.sender == address(this), BaseErrors.message_sender_is_not_my_owner);
        tvm.rawReserve(_reserve(), 0);

        address manager = callbackParams.value != 0 && sellProxy != address(0) ? sellProxy : owner;
        mapping(address => ITIP4_1NFT.CallbackParams) callbacks;
        uint128 sendToNftValue;

        if (manager == sellProxy) {
            callbacks[sellProxy] = callbackParams;
            sendToNftValue = _sendToNftValue() + callbackParams.value;
        } else {
            callbacks = emptyMap;
            sendToNftValue = _sendToNftValue();
        }

        _totalSupply++;
        _lastTokenId++;
        uint256 id = _lastTokenId;
        /// @notice Start editionNumber with 1 instead of 0
        uint32 editionNumber = currentIteration + 1;

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
            owner,
            owner,
            manager,
            json,
            licenseURI,
            licenseName,
            royalty,
            editionId,
            amount,
            editionNumber,
            callbacks
        );

        address nftAddress = new NftPlatform{ stateInit: stateNft, value: sendToNftValue, flag: 0 }(
            _buildNftCode(address(this), _codeNft),
            data,
            _remainOnNft
        );

        emit NftCreated(id, nftAddress, owner, manager, owner);
        emit BulkNftCreated(id, nftAddress, owner, manager, owner, json, editionId, amount, editionNumber);

        currentIteration++;
        _invokeMint(
            owner,
            royalty,
            json,
            callbackParams,
            sellProxy,
            licenseURI,
            licenseName,
            editionId,
            amount,
            currentIteration
        );
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
                _editionsSupply,
                _sendToProxyValue,
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
            _editionsSupply,
            _sendToProxyValue,
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
                uint128,
                uint128,
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

    /// @return supply Amount of editions in collection
    function editionsSupply() external view virtual responsible override returns (uint128 supply) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } (_editionsSupply);
    }

    function sendToProxyValue() external view virtual responsible override returns (uint128 value) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } (_sendToProxyValue);
    }

    function _sendToNftValue() internal view virtual returns (uint128) {
        return _remainOnNft + (2 * _indexDeployValue) + (2 * _methodsCallsFee);
    }

    function _totalCreationPrice() internal view virtual override returns (uint128) {
        return _mintingFee + _minimalGasAmount + _sendToNftValue() + (_methodsCallsFee * 2) + _sendToProxyValue;
    }

    function _buildNftState(TvmCell code, uint256 id) internal pure virtual override returns (TvmCell) {
        return tvm.buildStateInit({ contr: NftBulkUpgradeable, varInit: { _id: id }, code: code });
    }

    function supportsInterface(bytes4 interfaceID) external view virtual responsible override returns (bool) {
        return
            { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } (interfaceID ==
                bytes4(tvm.functionId(ITIP6.supportsInterface)) ||
                interfaceID ==
                bytes4(tvm.functionId(ITIP4_1Collection.totalSupply)) ^
                    bytes4(tvm.functionId(ITIP4_1Collection.nftCode)) ^
                    bytes4(tvm.functionId(ITIP4_1Collection.nftCodeHash)) ^
                    bytes4(tvm.functionId(ITIP4_1Collection.nftAddress)) ||
                interfaceID == bytes4(tvm.functionId(ITIP4_2JSON_Metadata.getJson)) ||
                interfaceID ==
                bytes4(tvm.functionId(ITIP4_3Collection.indexBasisCode)) ^
                    bytes4(tvm.functionId(ITIP4_3Collection.indexBasisCodeHash)) ^
                    bytes4(tvm.functionId(ITIP4_3Collection.indexCode)) ^
                    bytes4(tvm.functionId(ITIP4_3Collection.indexCodeHash)) ^
                    bytes4(tvm.functionId(ITIP4_3Collection.resolveIndexBasis)) ||
                interfaceID == bytes4(tvm.functionId(ITokenBurned.onTokenBurned)) ||
                interfaceID == bytes4(tvm.functionId(ICollectionBase.getFeesInfo)) ||
                interfaceID == bytes4(tvm.functionId(IWithdrawalAddress.withdrawalAddress)) ||
                interfaceID == bytes4(tvm.functionId(IDestroy.destroy)) ||
                interfaceID ==
                bytes4(tvm.functionId(ITIP4_6Collection.nftVersion)) ^
                    bytes4(tvm.functionId(ITIP4_6Collection.platformCode)) ^
                    bytes4(tvm.functionId(ITIP4_6Collection.platformCodeInfo)) ||
                interfaceID ==
                bytes4(tvm.functionId(ICollectionUpgradeable.collectionVersion)) ^
                    bytes4(tvm.functionId(ICollectionUpgradeable.requestNftUpgrade)) ^
                    bytes4(tvm.functionId(ICollectionUpgradeable.requestUpgrade)) ^
                    bytes4(tvm.functionId(ICollectionUpgradeable.acceptUpgrade)) ^
                    bytes4(tvm.functionId(ICollectionUpgradeable.requestUpdateNftCode)) ^
                    bytes4(tvm.functionId(ICollectionUpgradeable.acceptUpdateNftCode)) ||
                interfaceID ==
                bytes4(tvm.functionId(ICollectionBulk.editionsSupply)) ^
                    bytes4(tvm.functionId(ICollectionBulk.sendToProxyValue)));
    }
}
