interface ICollectionBase {
    /// @param id Unique Collection ID
    /// @param collectionRoot CollectionsRoot address
    /// @param author Collection author (creator) address
    /// @param json Collection json corresponding to TIP-4.2 standart
    /// @param isProtected If only author can mint to collection or not
    event CollectionCreated(uint256 id, address collectionRoot, address author, string json, bool isProtected);

    /// @notice All fees values getter
    /// @return totalCreationPrice - Sum of all values used in mint method
    /// @return mintingFee - Value that Collection contract takes itself for every mint
    /// @return methodsCallsFee - Value to be sent with some methods calls (like call of CollectionsFactory contract during collection deployment)
    /// @return minimalGasAmount - Value for processing mint method
    /// @return remainOnNft - Value that will be left on NFT after the entire mint process is completed
    /// @return indexDeployValue - Value for NFT index deployment
    /// @return indexDestroyValue - Value for NFT index destruction
    /// @return deployIndexBasisValue - Value for Collection index deployment
    /// @return nftBurnFee - Value that is needed for burn
    function getFeesInfo()
        external
        view
        responsible
        returns (
            uint128 totalCreationPrice,
            uint128 mintingFee,
            uint128 methodsCallsFee,
            uint128 minimalGasAmount,
            uint128 remainOnNft,
            uint128 indexDeployValue,
            uint128 indexDestroyValue,
            uint128 deployIndexBasisValue,
            uint128 nftBurnFee
        );
}
