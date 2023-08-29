interface ITIP4_6Collection {
    event UpgradeNftRequested(uint32 oldVersion, uint32 newVersion, address nft, address initiator);
    event NftCodeUpdated(uint32 oldVersion, uint32 newVersion, uint256 oldCodeHash, uint256 newCodeHash);

    function nftVersion() external view responsible returns (uint32);

    function platformCode() external view responsible returns (TvmCell);

    function platformCodeInfo() external view responsible returns (uint256 codeHash, uint16 codeDepth);

    function gasUpgradeValue() external view responsible returns (uint128 fixedValue, uint128 dynamicValue);
}
