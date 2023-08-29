interface ITIP4_6Nft {
    event NftUpgraded(uint32 oldVersion, uint32 newVersion);
    
    function version() external view responsible returns (uint32);

    function requestUpgrade(address sendGasTo) external;
}
