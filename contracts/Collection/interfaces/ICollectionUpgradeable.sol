interface ICollectionUpgradeable {
    event CollectionUpgraded(uint32 oldVersion, uint32 newVersion);
    
    function collectionVersion() external view responsible returns (uint32);

    function requestNftUpgrade(uint32 currentVersion, uint256 id, address initiator, address sendGasTo) external;

    function requestUpgrade(address sendGasTo) external;

    function acceptUpgrade(
        TvmCell newCode,
        TvmCell newData,
        uint32 newVersion,
        uint128 remainOnCollection,
        address sendGasTo
    ) external;

    function requestUpdateNftCode(address sendGasTo) external;

    function acceptUpdateNftCode(
        TvmCell newCode,
        TvmCell newData,
        uint32 newVersion,
        uint128 remainOnCollection,
        address sendGasTo
    ) external;
}
