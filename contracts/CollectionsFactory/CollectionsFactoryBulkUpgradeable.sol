pragma ton-solidity ^0.58.1;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./CollectionsfactoryUpgradeableBase.sol";
import "../Collection/CollectionBulkUpgradeable.sol";

contract CollectionsFactoryBulkUpgradeable is CollectionsFactoryUpgradeableBase {
    event BulkCollectionCreated(uint256 id, address collection, address author, string json, bool isProtected);

    /// @notice Value that will be sent to proxy contract on creation with selling
    uint128 _sendToProxyValue;

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
        TvmCell collectionPlatformCode,
        uint128 sendToProxyValue
    )
        public
        CollectionsFactoryUpgradeableBase(
            codeCollection,
            codeNft,
            codeIndex,
            codeIndexBasis,
            ownerPubkey,
            withdrawalAddress,
            creationPrice,
            nftMintingFee,
            nftPlatformCode,
            collectionPlatformCode
        )
    {
        _sendToProxyValue = sendToProxyValue;
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
            uint128(0),
            _sendToProxyValue,
            _nftVersion,
            _collectionVersion,
            _collectionVersion
        );
        addrCollection = new CollectionPlatform{ stateInit: state, value: 0, flag: 128 }(
            _buildCollectionCode(address(this)),
            data
        );

        emit CollectionCreated(id, addrCollection, msg.sender, json, isProtected);
        emit BulkCollectionCreated(id, addrCollection, msg.sender, json, isProtected);
    }

    function upgrade(TvmCell newCode) external onlyOwner {
        _version++;
        TvmCell data = abi.encode(
            _owner,
            _codeCollection,
            _codeNft,
            _codeIndex,
            _codeIndexBasis,
            _withdrawalAddress,
            _remainOnCollection,
            _minimalGasAmount,
            _creationPrice,
            _deployIndexBasisValue,
            _nftMintingFee,
            _methodsCallsFee,
            _collectionsMinimalGasAmount,
            _indexDeployValue,
            _indexDestroyValue,
            _totalSupply,
            _deploymentIsActive,
            _nftPlatformCode,
            _collectionPlatformCode,
            _version,
            _nftVersion,
            _collectionVersion,
            _collectionsFactoryVersion,
            _upgradedNftData,
            _upgradedCollectionData,
            _remainOnNft,
            _nftBurnFee
        );
        tvm.setcode(newCode);
        tvm.setCurrentCode(newCode);
        onCodeUpgrade(data);
    }

    function onCodeUpgrade(TvmCell data) private {}

    function sendToProxyValue() external view responsible returns (uint128 value) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } (_sendToProxyValue);
    }

    function setSendToProxyValue(uint128 value) external onlyOwner {
        _sendToProxyValue = value;
    }

    function _totalCreationPrice() internal view virtual override returns (uint128) {
        return
            _remainOnCollection + _creationPrice + _deployIndexBasisValue + _minimalGasAmount + (_methodsCallsFee * 3);
    }

    function _buildCollectionState(TvmCell code, uint256 id) internal pure virtual override returns (TvmCell) {
        return tvm.buildStateInit({ contr: CollectionBulkUpgradeable, varInit: { _id: id }, code: code });
    }
}
