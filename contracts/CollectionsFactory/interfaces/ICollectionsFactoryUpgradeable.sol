interface ICollectionsFactoryUpgradeable {
    event NftCodeUpdated(uint32 oldVersion, uint32 newVersion, uint256 oldCodeHash, uint256 newCodeHash);
    event CollectionCodeUpdated(uint32 oldVersion, uint32 newVersion, uint256 oldCodeHash, uint256 newCodeHash);
    event UpdateNftCodeRequested(uint32 oldVersion, uint32 newVersion, address collection);
    event UpgradeCollectionCodeRequested(uint32 oldVersion, uint32 newVersion, address collection);

    function requestCollectionUpgrade(uint32 currentVersion, uint256 id, address sendGasTo) external;

    function requestUpdateNftCode(uint32 currentNftVersion, uint256 collectionId, address sendGasTo) external;

    function nftVersion() external view responsible returns (uint32);

    function collectionVersion() external view responsible returns (uint32);

    function gasUpgradeValue() external view responsible returns (uint128 fixedValue, uint128 dynamicValue);

    function collectionPlatformCode() external view responsible returns (TvmCell);

    function collectionPlatformCodeInfo() external view responsible returns (uint256 codeHash, uint16 codeDepth);

    function nftPlatformCodeOriginal() external view responsible returns (TvmCell);

    function nftCodeOriginal() external view responsible returns (TvmCell);

    function nftPlatformCodeHashOriginal() external view responsible returns (uint256);

    function nftCodeHashOriginal() external view responsible returns (uint256);
}
