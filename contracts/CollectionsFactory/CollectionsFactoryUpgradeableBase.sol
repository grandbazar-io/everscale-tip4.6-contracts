pragma ton-solidity ^0.58.1;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./CollectionsFactoryBase.sol";
import "../Collection/CollectionPlatform.sol";
import "../Collection/interfaces/ICollectionUpgradeable.sol";
import "./interfaces/ICollectionsFactoryUpgradeable.sol";
import "../Collection/CollectionUpgradeable.sol";

abstract contract CollectionsFactoryUpgradeableBase is CollectionsFactoryBase, ICollectionsFactoryUpgradeable {
    TvmCell _nftPlatformCode;
    TvmCell _collectionPlatformCode;
    uint32 _version;
    uint32 _nftVersion;
    uint32 _collectionVersion;
    uint32 _collectionsFactoryVersion;
    TvmCell _upgradedNftData;
    TvmCell _upgradedCollectionData;
    uint128 _remainOnNft = 0.3 ever;
    uint128 _nftBurnFee = 0.4 ever;

    constructor(
        TvmCell codeCollection,
        TvmCell codeNft,
        TvmCell codeIndex,
        TvmCell codeIndexBasis,
        uint256 ownerPubkey,
        address withdrawalAddress,
        uint128 creationPrice,
        uint128 nftMintingFee,
        TvmCell nftPlatformCode,
        TvmCell collectionPlatformCode
    )
        public
        CollectionsFactoryBase(
            codeCollection,
            codeNft,
            codeIndex,
            codeIndexBasis,
            ownerPubkey,
            withdrawalAddress,
            creationPrice,
            nftMintingFee
        )
    {
        _nftPlatformCode = nftPlatformCode;
        _collectionPlatformCode = collectionPlatformCode;

        _supportedInterfaces[
            bytes4(tvm.functionId(ICollectionsFactoryUpgradeable.requestCollectionUpgrade)) ^
                bytes4(tvm.functionId(ICollectionsFactoryUpgradeable.requestUpdateNftCode)) ^
                bytes4(tvm.functionId(ICollectionsFactoryUpgradeable.nftVersion)) ^
                bytes4(tvm.functionId(ICollectionsFactoryUpgradeable.collectionVersion)) ^
                bytes4(tvm.functionId(ICollectionsFactoryUpgradeable.gasUpgradeValue)) ^
                bytes4(tvm.functionId(ICollectionsFactoryUpgradeable.collectionPlatformCode)) ^
                bytes4(tvm.functionId(ICollectionsFactoryUpgradeable.collectionPlatformCodeInfo)) ^
                bytes4(tvm.functionId(ICollectionsFactoryUpgradeable.nftPlatformCodeOriginal)) ^
                bytes4(tvm.functionId(ICollectionsFactoryUpgradeable.nftCodeOriginal)) ^
                bytes4(tvm.functionId(ICollectionsFactoryUpgradeable.nftPlatformCodeHashOriginal)) ^
                bytes4(tvm.functionId(ICollectionsFactoryUpgradeable.nftCodeHashOriginal))
        ] = true;
    }

    /// @param json collection info
    /// @param sendGasTo address that will get all the change
    /// @param isProtected if set to true, then only author can mint NFT
    function deployCollection(
        string json,
        address sendGasTo,
        bool isProtected
    ) external virtual override returns (address addrCollection) {
        require(_deploymentIsActive, deployment_is_not_active);
        require(msg.value >= _totalCreationPrice(), BaseErrors.not_enough_value);
        // Reserve original_balance + _creationPrice
        tvm.rawReserve(_creationPrice, 4);

        uint256 id = _totalSupply;
        _totalSupply++;

        TvmCell code = _buildCollectionPlatformCode(address(this));
        TvmCell state = _buildCollectionPlatformState(code, id);
        TvmCell emptyCell;
        TvmCell data = abi.encode(
            id,
            _codeNft,
            _codeIndex,
            _codeIndexBasis,
            _nftPlatformCode,
            _upgradedNftData,
            emptyCell,
            emptyCell,
            uint128(0),
            _indexDeployValue,
            _indexDestroyValue,
            _deployIndexBasisValue,
            _remainOnNft,
            _remainOnCollection,
            _methodsCallsFee,
            _nftBurnFee,
            _minimalGasAmount,
            _nftMintingFee,
            _withdrawalAddress,
            msg.sender,
            msg.sender,
            isProtected,
            sendGasTo,
            uint256(0),
            json,
            _nftVersion,
            _collectionVersion,
            _collectionVersion
        );
        addrCollection = new CollectionPlatform{ stateInit: state, value: 0, flag: MsgFlags.ALL_NOT_RESERVED }(
            _buildCollectionCode(address(this)),
            data
        );

        emit CollectionCreated(id, addrCollection, msg.sender, json, isProtected);
    }

    function requestCollectionUpgrade(uint32 currentVersion, uint256 id, address sendGasTo) external virtual override {
        require(msg.sender == _resolveCollection(id), BaseErrors.message_sender_is_not_my_data);
        tvm.rawReserve(0, 4);

        if (currentVersion == _collectionVersion) {
            sendGasTo.transfer({ value: 0, flag: MsgFlags.ALL_NOT_RESERVED, bounce: false });
        } else {
            emit UpgradeCollectionCodeRequested(currentVersion, _collectionVersion, msg.sender);
            ICollectionUpgradeable(msg.sender).acceptUpgrade{
                value: 0,
                flag: MsgFlags.ALL_NOT_RESERVED,
                bounce: false
            }(
                _buildCollectionCode(address(this)),
                _upgradedCollectionData,
                _collectionVersion,
                _remainOnCollection,
                sendGasTo
            );
        }
    }

    function requestUpdateNftCode(
        uint32 currentNftVersion,
        uint256 collectionId,
        address sendGasTo
    ) external virtual override {
        require(msg.sender == _resolveCollection(collectionId), BaseErrors.message_sender_is_not_my_data);
        tvm.rawReserve(0, 4);
        if (currentNftVersion == _nftVersion) {
            sendGasTo.transfer({ value: 0, flag: MsgFlags.ALL_NOT_RESERVED, bounce: false });
        } else {
            emit UpdateNftCodeRequested(currentNftVersion, _nftVersion, msg.sender);
            ICollectionUpgradeable(msg.sender).acceptUpdateNftCode{
                value: 0,
                flag: MsgFlags.ALL_NOT_RESERVED,
                bounce: false
            }(_codeNft, _upgradedNftData, _nftVersion, _remainOnCollection, sendGasTo);
        }
    }

    function updateNftCode(TvmCell code) external virtual onlyOwner {
        uint32 oldVersion = _nftVersion;
        TvmCell oldCode = _codeNft;
        _codeNft = code;
        _nftVersion++;

        emit NftCodeUpdated(oldVersion, _nftVersion, tvm.hash(oldCode), tvm.hash(_codeNft));
    }

    function setNewNftData(TvmCell newData) external virtual onlyOwner {
        _upgradedNftData = newData;
    }

    function updateCollectionCode(TvmCell code) external virtual onlyOwner {
        uint32 oldVersion = _collectionVersion;
        TvmCell oldCode = _codeCollection;
        _codeCollection = code;
        _collectionVersion++;

        emit CollectionCodeUpdated(oldVersion, _collectionVersion, tvm.hash(oldCode), tvm.hash(_codeCollection));
    }

    function setNewCollectionData(TvmCell newData) external virtual onlyOwner {
        _upgradedCollectionData = newData;
    }

    function nftVersion() external view responsible override returns (uint32) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } _nftVersion;
    }

    function collectionVersion() external view responsible override returns (uint32) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } _collectionVersion;
    }

    function collectionPlatformCode() external view responsible override returns (TvmCell) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } _buildCollectionPlatformCode(address(this));
    }

    function gasUpgradeValue() external view responsible override returns (uint128 fixedValue, uint128 dynamicValue) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } (GasValues.NFT_UPGRADE_VALUE, 0);
    }

    function collectionPlatformCodeInfo()
        external
        view
        responsible
        override
        returns (uint256 codeHash, uint16 codeDepth)
    {
        TvmCell code = _buildCollectionPlatformCode(address(this));
        return { value: 0, flag: 64, bounce: false } (tvm.hash(code), code.depth());
    }

    function nftPlatformCodeOriginal() external view responsible override returns (TvmCell) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } _nftPlatformCode;
    }

    function nftCodeOriginal() external view responsible override returns (TvmCell) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } _codeNft;
    }

    function nftPlatformCodeHashOriginal() external view responsible override returns (uint256) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } tvm.hash(_nftPlatformCode);
    }

    function nftCodeHashOriginal() external view responsible override returns (uint256) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } tvm.hash(_codeNft);
    }

    /// @notice Resolve nft address used addrRoot & nft id
    /// @param id Unique nft number
    function _resolveCollection(uint256 id) internal view virtual override returns (address collection) {
        TvmCell code = _buildCollectionPlatformCode(address(this));
        TvmCell state = _buildCollectionPlatformState(code, id);
        uint256 hashState = tvm.hash(state);
        collection = address.makeAddrStd(address(this).wid, hashState);
    }

    function _buildCollectionPlatformCode(address collectionsRoot) internal view virtual returns (TvmCell) {
        TvmBuilder salt;
        salt.store(collectionsRoot);
        return tvm.setCodeSalt(_collectionPlatformCode, salt.toCell());
    }

    function _buildCollectionPlatformState(TvmCell code, uint256 id) internal pure virtual returns (TvmCell) {
        return tvm.buildStateInit({ contr: CollectionPlatform, varInit: { _id: id }, code: code });
    }

    function _buildCollectionState(TvmCell code, uint256 id) internal pure virtual override returns (TvmCell) {
        return tvm.buildStateInit({ contr: CollectionUpgradeable, varInit: { _id: id }, code: code });
    }
}
