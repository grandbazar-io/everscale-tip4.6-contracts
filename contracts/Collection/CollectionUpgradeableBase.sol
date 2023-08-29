pragma ton-solidity ^0.58.1;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "../libraries/MsgFlags.sol";
import "./CollectionBase.sol";
import "../Nft/NftUpgradeable.sol";
import "./interfaces/ITIP4_6Collection.sol";
import "./interfaces/ICollectionUpgradeable.sol";
import "../Nft/NftPlatform.sol";
import "../Nft/interfaces/INftUpgradeable.sol";
import "../CollectionsFactory/interfaces/ICollectionsFactoryUpgradeable.sol";

abstract contract CollectionUpgradeableBase is CollectionBase, ITIP4_6Collection, ICollectionUpgradeable {
    mapping(bytes4 => bool) internal _supportedInterfaces;

    TvmCell _nftPlatformCode;
    uint32 _nftVersion;
    uint32 _collectionVersion;
    TvmCell _upgradedNftData;

    constructor() public {
        revert();
    }

    function nftVersion() external view responsible override returns (uint32) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } _nftVersion;
    }

    function platformCode() external view responsible override returns (TvmCell) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } _buildPlatformCode(address(this));
    }

    function platformCodeInfo()
        external
        view
        virtual
        responsible
        override
        returns (uint256 codeHash, uint16 codeDepth)
    {
        return
            { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } (
                tvm.hash(_buildPlatformCode(address(this))),
                _nftPlatformCode.depth()
            );
    }

    function collectionVersion() external view responsible override returns (uint32) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } _collectionVersion;
    }

    function gasUpgradeValue() external view responsible override returns (uint128 fixedValue, uint128 dynamicValue) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } (GasValues.COLLECTION_UPGRADE_VALUE, 0);
    }

    function requestUpgrade(address sendGasTo) external virtual override onlyOwner {
        ICollectionsFactoryUpgradeable(_collectionsRoot).requestCollectionUpgrade{
            value: 0,
            flag: MsgFlags.REMAINING_GAS,
            bounce: false
        }(_collectionVersion, _id, sendGasTo);
    }

    function requestUpdateNftCode(address sendGasTo) external virtual override onlyOwner {
        ICollectionsFactoryUpgradeable(_collectionsRoot).requestUpdateNftCode{
            value: 0,
            flag: MsgFlags.REMAINING_GAS,
            bounce: false
        }(_nftVersion, _id, sendGasTo);
    }

    function acceptUpdateNftCode(
        TvmCell newCode,
        TvmCell newData,
        uint32 newVersion,
        uint128 remainOnCollection,
        address sendGasTo
    ) external virtual override onlyCollectionsRoot {
        tvm.rawReserve(remainOnCollection, 2);
        if (_nftVersion == newVersion) {
            sendGasTo.transfer({ value: 0, flag: MsgFlags.ALL_NOT_RESERVED + MsgFlags.IGNORE_ERRORS, bounce: false });
        } else {
            emit NftCodeUpdated(
                _nftVersion,
                newVersion,
                tvm.hash(_buildNftCode(address(this), _codeNft)),
                tvm.hash(_buildNftCode(address(this), newCode))
            );
            _codeNft = newCode;
            _nftVersion = newVersion;
            _upgradedNftData = newData;

            if (sendGasTo.value != 0 && sendGasTo != address(this)) {
                sendGasTo.transfer({
                    value: 0,
                    flag: MsgFlags.ALL_NOT_RESERVED + MsgFlags.IGNORE_ERRORS,
                    bounce: false
                });
            }
        }
    }

    function requestNftUpgrade(
        uint32 currentVersion,
        uint256 id,
        address initiator,
        address sendGasTo
    ) external virtual override {
        require(msg.sender == _resolveNft(id), BaseErrors.message_sender_is_not_my_data);
        tvm.rawReserve(0, 4);

        if (currentVersion == _nftVersion) {
            sendGasTo.transfer({ value: 0, flag: MsgFlags.ALL_NOT_RESERVED, bounce: false });
        } else {
            emit UpgradeNftRequested(currentVersion, _nftVersion, initiator, msg.sender);
            INftUpgradeable(msg.sender).acceptUpgrade{ value: 0, flag: MsgFlags.ALL_NOT_RESERVED, bounce: false }(
                _buildNftCode(address(this), _codeNft),
                _upgradedNftData,
                _nftVersion,
                _remainOnNft,
                sendGasTo
            );
        }
    }

    /// @notice Resolve nft address used addrRoot & nft id
    /// @param id Unique nft number
    function _resolveNft(uint256 id) internal view virtual override returns (address nft) {
        TvmCell code = _buildPlatformCode(address(this));
        TvmCell state = _buildPlatformState(code, id);
        uint256 hashState = tvm.hash(state);
        nft = address.makeAddrStd(address(this).wid, hashState);
    }

    /// @notice Generates a StateInit from code and data
    /// @param code TvmCell code - generated via the _buildNftCode method
    /// @return TvmCell object - stateInit
    /// about tvm.buildStateInit read more here (https://github.com/tonlabs/ton-solidity-Compiler/blob/master/API.md#tvmbuildstateinit)
    function _buildNftState(TvmCell code, uint256 id) internal pure virtual override returns (TvmCell) {
        return tvm.buildStateInit({ contr: NftUpgradeable, varInit: { _id: id }, code: code });
    }

    function _buildPlatformCode(address collection) internal view virtual returns (TvmCell) {
        TvmBuilder salt;
        salt.store(collection);
        return tvm.setCodeSalt(_nftPlatformCode, salt.toCell());
    }

    function _buildPlatformState(TvmCell code, uint256 id) internal pure virtual returns (TvmCell) {
        return tvm.buildStateInit({ contr: NftPlatform, varInit: { _id: id }, code: code });
    }

    function supportsInterface(bytes4 interfaceID) external view virtual responsible override returns (bool) {
        return
            { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } (interfaceID ==
                bytes4(tvm.functionId(ITIP6.supportsInterface)) ||
                interfaceID ==
                bytes4(tvm.functionId(ITIP4_1Collection.totalSupply)) ^
                    bytes4(tvm.functionId(ITIP4_1Collection.nftCode)) ^
                    bytes4(tvm.functionId(ITIP4_1Collection.nftCodeHash)) ^
                    bytes4(tvm.functionId(ITIP4_1Collection.nftAddress)) ||
                interfaceID == bytes4(tvm.functionId(ITIP4_2JSON_Metadata.getJson)) ||
                interfaceID ==
                bytes4(tvm.functionId(ITIP4_3Collection.indexBasisCode)) ^
                    bytes4(tvm.functionId(ITIP4_3Collection.indexBasisCodeHash)) ^
                    bytes4(tvm.functionId(ITIP4_3Collection.indexCode)) ^
                    bytes4(tvm.functionId(ITIP4_3Collection.indexCodeHash)) ^
                    bytes4(tvm.functionId(ITIP4_3Collection.resolveIndexBasis)) ||
                interfaceID == bytes4(tvm.functionId(ITokenBurned.onTokenBurned)) ||
                interfaceID == bytes4(tvm.functionId(ICollectionBase.getFeesInfo)) ||
                interfaceID == bytes4(tvm.functionId(IWithdrawalAddress.withdrawalAddress)) ||
                interfaceID == bytes4(tvm.functionId(IDestroy.destroy)) ||
                interfaceID ==
                bytes4(tvm.functionId(ITIP4_6Collection.nftVersion)) ^
                    bytes4(tvm.functionId(ITIP4_6Collection.platformCode)) ^
                    bytes4(tvm.functionId(ITIP4_6Collection.platformCodeInfo)) ^
                    bytes4(tvm.functionId(ITIP4_6Collection.gasUpgradeValue)) ||
                interfaceID ==
                bytes4(tvm.functionId(ICollectionUpgradeable.collectionVersion)) ^
                    bytes4(tvm.functionId(ICollectionUpgradeable.requestNftUpgrade)) ^
                    bytes4(tvm.functionId(ICollectionUpgradeable.requestUpgrade)) ^
                    bytes4(tvm.functionId(ICollectionUpgradeable.acceptUpgrade)) ^
                    bytes4(tvm.functionId(ICollectionUpgradeable.requestUpdateNftCode)) ^
                    bytes4(tvm.functionId(ICollectionUpgradeable.acceptUpdateNftCode)));
    }
}
