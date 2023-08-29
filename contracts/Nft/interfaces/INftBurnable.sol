interface INftBurnable {
    function burn(address sendGasTo) external;

    function burnFee() external view responsible returns (uint128);
}
