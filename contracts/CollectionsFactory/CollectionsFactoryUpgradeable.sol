pragma ton-solidity ^0.58.1;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./CollectionsfactoryUpgradeableBase.sol";

contract CollectionsFactoryUpgradeable is CollectionsFactoryUpgradeableBase {
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
    {}

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
}
