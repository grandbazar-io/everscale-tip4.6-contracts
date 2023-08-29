pragma ton-solidity ^0.58.1;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./NftUpgradeableBase.sol";
import "../abstract/interfaces/IEdition.sol";
import "../abstract/interfaces/INftCreated.sol";

contract NftBulkUpgradeable is NftUpgradeableBase, IEdition {
    uint128 _editionId;
    uint32 _editionSupply;
    uint32 _editionNumber;

    function acceptUpgrade(
        TvmCell newCode,
        TvmCell newData,
        uint32 newVersion,
        uint128 remainOnNft,
        address sendGasTo
    ) external virtual override onlyCollection {
        if (_version == newVersion) {
            tvm.rawReserve(remainOnNft, 2);
            sendGasTo.transfer({ value: 0, flag: MsgFlags.ALL_NOT_RESERVED + MsgFlags.IGNORE_ERRORS, bounce: false });
        } else {
            TvmCell data;
            TvmCell newStorageData;
            data = abi.encode(
                _id,
                _codeIndex,
                newStorageData,
                newData,
                _indexDeployValue,
                _indexDestroyValue,
                remainOnNft,
                _version,
                newVersion,
                sendGasTo,
                _owner,
                _manager,
                _json,
                _licenseURI,
                _licenseName,
                _royalty,
                _editionId,
                _editionSupply,
                _editionNumber
            );

            tvm.setcode(newCode);
            tvm.setCurrentCode(newCode);
            onCodeUpgrade(data);
        }
    }

    function onCodeUpgrade(TvmCell data) private {
        tvm.resetStorage();
        optional(TvmCell) optSalt = tvm.codeSalt(tvm.code());
        _collection = optSalt.get().toSlice().decode(address);
        uint32 oldVersion;

        uint128 remainOnNft;
        TvmCell newStorageData;
        TvmCell upgradeData;
        address sendGasTo;
        mapping(address => CallbackParams) callbacks;

        (
            _id,
            _codeIndex,
            newStorageData,
            upgradeData,
            _indexDeployValue,
            _indexDestroyValue,
            remainOnNft,
            oldVersion,
            _version,
            sendGasTo,
            _owner,
            _manager,
            _json,
            _licenseURI,
            _licenseName,
            _royalty,
            _editionId,
            _editionSupply,
            _editionNumber,
            callbacks
        ) = abi.decode(
            data,
            (
                uint256,
                TvmCell,
                TvmCell,
                TvmCell,
                uint128,
                uint128,
                uint128,
                uint32,
                uint32,
                address,
                address,
                address,
                string,
                string,
                string,
                mapping(address => uint8),
                uint128,
                uint32,
                uint32,
                mapping(address => CallbackParams)
            )
        );

        /// @dev Logic for setting new storage data coming from collection
        TvmSlice newDataSlice = newStorageData.toSlice();
        if (!newDataSlice.empty()) {}

        tvm.rawReserve(remainOnNft, 2);

        if (_version == oldVersion) {
            _deployIndex();

            emit NftCreated(_id, _owner, _manager, _collection);
            for ((address dest, CallbackParams p): callbacks) {
                INftCreated(dest).onNftCreated{ value: p.value, flag: 0 + 1, bounce: false }(
                    _id,
                    _owner,
                    _manager,
                    _collection,
                    sendGasTo,
                    p.payload
                );
            }
        } else {
            emit NftUpgraded(oldVersion, _version);
        }

        if (sendGasTo.value != 0 && sendGasTo != address(this)) {
            sendGasTo.transfer({ value: 0, flag: MsgFlags.ALL_NOT_RESERVED + MsgFlags.IGNORE_ERRORS, bounce: false });
        }
    }

    function editionInfo()
        external
        view
        virtual
        responsible
        override
        returns (uint128 editionId, uint32 editionSupply, uint32 editionNumber)
    {
        return { value: 0, flag: 64, bounce: false } (_editionId, _editionSupply, _editionNumber);
    }

    function supportsInterface(bytes4 interfaceID) external view virtual responsible override returns (bool) {
        return
            { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } (interfaceID ==
                bytes4(tvm.functionId(ITIP6.supportsInterface)) ||
                interfaceID ==
                bytes4(tvm.functionId(ITIP4_1NFT.getInfo)) ^
                    bytes4(tvm.functionId(ITIP4_1NFT.changeOwner)) ^
                    bytes4(tvm.functionId(ITIP4_1NFT.changeManager)) ^
                    bytes4(tvm.functionId(ITIP4_1NFT.transfer)) ||
                interfaceID == bytes4(tvm.functionId(ITIP4_2JSON_Metadata.getJson)) ||
                interfaceID ==
                bytes4(tvm.functionId(ITIP4_3NFT.indexCode)) ^
                    bytes4(tvm.functionId(ITIP4_3NFT.indexCodeHash)) ^
                    bytes4(tvm.functionId(ITIP4_3NFT.resolveIndex)) ||
                interfaceID ==
                bytes4(tvm.functionId(ITIP4_5.getLicenseURI)) ^ bytes4(tvm.functionId(ITIP4_5.getLicenseName)) ||
                interfaceID ==
                bytes4(tvm.functionId(INftBurnable.burn)) ^ bytes4(tvm.functionId(INftBurnable.burnFee)) ||
                interfaceID == bytes4(tvm.functionId(IRoyalty.royaltyInfo)) ||
                interfaceID ==
                bytes4(tvm.functionId(ITIP4_6Nft.version)) ^ bytes4(tvm.functionId(ITIP4_6Nft.requestUpgrade)) ||
                interfaceID == bytes4(tvm.functionId(IEdition.editionInfo)));
    }
}
