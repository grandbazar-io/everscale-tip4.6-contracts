pragma ton-solidity ^0.58.1;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "../TIP/TIP4_2/TIP4_2Collection.sol";
import "../TIP/TIP4_3/TIP4_3Collection.sol";
import "../libraries/GasValues.sol";
import "@itgold/everscale-tip/contracts/access/OwnableExternal.sol";
import "../abstract/interfaces/ITokenBurned.sol";
import "./interfaces/ICollectionBase.sol";
import "../abstract/interfaces/IWithdrawalAddress.sol";
import "../abstract/interfaces/IDestroy.sol";
import "../libraries/BaseErrors.sol";

abstract contract CollectionBase is
    TIP4_2Collection,
    TIP4_3Collection,
    ITokenBurned,
    ICollectionBase,
    IWithdrawalAddress,
    IDestroy
{
    uint256 static _id;
    address _collectionsRoot;
    address _owner;
    address _author;
    bool _isProtected;
    /// _remainOnNft - the number of evers that will remain after the entire mint
    /// process is completed on the Nft contract
    uint128 _remainOnNft = 0.3 ever;
    /// Value to be sent with some methods calls (like call of CollectionRoot contract during collection deploy)
    uint128 _methodsCallsFee = 0.1 ever;
    uint128 _nftBurnFee = 0.4 ever;
    uint128 _minimalGasAmount = 0.2 ever;
    uint128 _mintingFee;

    address _withdrawalAddress;

    uint256 _lastTokenId;

    /// @notice Method that NFT can call on its burn
    /// @param id Unique NFT ID
    /// @param owner NFT owner
    /// @param manager NFT manager
    /// @param sendGasTo Change recipient address
    function onTokenBurned(uint256 id, address owner, address manager, address sendGasTo) external virtual override {
        require(msg.sender == _resolveNft(id), BaseErrors.message_sender_is_not_my_data);
        tvm.rawReserve(_reserve(), 0);
        emit NftBurned(id, msg.sender, owner, manager);
        _totalSupply--;
        sendGasTo.transfer({ value: 0, flag: 128 });
    }

    /// @notice Owner can destroy collection if there are not minted NFT
    /// @param sendGasTo Change recipient address
    function destroy(address sendGasTo) external virtual override onlyOwner {
        require(_totalSupply == 0, BaseErrors.total_supply_is_more_than_zero);
        require(msg.value >= _indexDestroyValue + _methodsCallsFee, BaseErrors.not_enough_value);

        TvmCell code = _buildIndexBasisCode();
        TvmCell state = _buildIndexBasisState(code, address(this));
        uint256 hashState = tvm.hash(state);
        address indexBasis = address.makeAddrStd(address(this).wid, hashState);
        IIndexBasis(indexBasis).destruct{ value: 0, flag: 128 + 32, bounce: false }(sendGasTo);
    }

    /// @notice returns current withdrawal address
    /// @return addr Current withdrawal address
    function withdrawalAddress() external view virtual responsible override returns (address addr) {
        return { value: 0, flag: 64, bounce: false } (_withdrawalAddress);
    }

    /// @notice All fees values getter
    /// @return totalCreationPrice - Sum of all values used in mint method
    /// @return mintingFee - Value that Collection contract takes itself for every mint
    /// @return methodsCallsFee - Value to be sent with some methods calls (like call of CollectionRoot contract during collection deployment)
    /// @return minimalGasAmount - Value for processing mint method
    /// @return remainOnNft - Value that will be left on NFT after the entire mint process is completed
    /// @return indexDeployValue - Value for NFT index deployment
    /// @return indexDestroyValue - Value for NFT index destruction
    /// @return deployIndexBasisValue - Value for Collection index deployment
    /// @return nftBurnFee - Value that is needed for burn
    function getFeesInfo()
        external
        view
        virtual
        responsible
        override
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
        )
    {
        return
            { value: 0, flag: 64, bounce: false } (
                _totalCreationPrice(),
                _mintingFee,
                _methodsCallsFee,
                _minimalGasAmount,
                _remainOnNft,
                _indexDeployValue,
                _indexDestroyValue,
                _deployIndexBasisValue,
                _nftBurnFee
            );
    }

    /// @notice Returns current NFT total creation price. It is used to avoid storing another variable and rewriting it on every fee change
    /// @return NFT total creation price
    function _totalCreationPrice() internal view virtual returns (uint128) {
        return _remainOnNft + _mintingFee + (2 * _indexDeployValue) + _methodsCallsFee + _minimalGasAmount;
    }

    /// @notice Generates a StateInit from code and data
    /// @param code TvmCell code - generated via the _buildNftCode method
    /// @param id Unique nft number
    /// @return TvmCell object - stateInit
    /// about tvm.buildStateInit read more here (https://github.com/tonlabs/ton-solidity-Compiler/blob/master/API.md#tvmbuildstateinit)
    function _buildNftState(
        TvmCell code,
        uint256 id
    ) internal pure virtual override(TIP4_2Collection, TIP4_3Collection) returns (TvmCell) {
        // return tvm.buildStateInit({ contr: Nft, varInit: { _id: id }, code: code });
    }

    function _reserve() internal pure returns (uint128) {
        return math.max(address(this).balance - msg.value, _targetBalance());
    }

    function _targetBalance() internal pure returns (uint128) {
        return GasValues.COLLECTION_TARGET_BALANCE;
    }

    modifier onlyOwner() virtual {
        require(_owner == msg.sender, 100);
        _;
    }

    modifier onlyCollectionsRoot() {
        require(msg.sender == _collectionsRoot, 100);
        _;
    }
}
