interface INftUpgradeable {
    function acceptUpgrade(
        TvmCell newCode,
        TvmCell newData,
        uint32 newVersion,
        uint128 remaionOnNft,
        address sendGasTo
    ) external;
}