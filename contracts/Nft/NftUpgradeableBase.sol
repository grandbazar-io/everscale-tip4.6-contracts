pragma ton-solidity ^0.58.1;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "./NftBase.sol";
import "./NftPlatform.sol";
import "../libraries/MsgFlags.sol";

import "./interfaces/ITIP4_6Nft.sol";
import "./interfaces/INftUpgradeable.sol";
import "../Collection/interfaces/ICollectionUpgradeable.sol";

abstract contract NftUpgradeableBase is NftBase, ITIP4_6Nft, INftUpgradeable {
    uint32 _version;
    TvmCell _platformCode;

    constructor() public {
        revert();
    }

    function version() external view responsible override returns (uint32) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } _version;
    }

    function requestUpgrade(address sendGasTo) external virtual override onlyManager {
        ICollectionUpgradeable(_collection).requestNftUpgrade{ value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false }(
            _version,
            _id,
            _manager,
            sendGasTo
        );
    }

    function _getExpectedAddress(address collection) internal view virtual returns (address nft) {
        TvmCell code = _buildPlatformCode(collection);
        TvmCell state = _buildPlatformState(code);
        uint256 hashState = tvm.hash(state);
        nft = address.makeAddrStd(address(this).wid, hashState);
    }

    /// @notice build NftPlatform code used TvmCell NftPlatform code & salt (address collection) ...
    /// ... to create unique nft address BC nft code & id can be repeated
    /// @param collection - collection address
    /// @return TvmCell NftPlatform code
    /// about salt read more here (https://github.com/tonlabs/ton-solidity-Compiler/blob/master/API.md#tvmcodesalt)
    function _buildPlatformCode(address collection) internal view virtual returns (TvmCell) {
        TvmBuilder salt;
        salt.store(collection);
        return tvm.setCodeSalt(_platformCode, salt.toCell());
    }

    /// @notice Generates a StateInit from code and data
    /// @param code TvmCell code - generated via the _buildPlatformCode method
    /// @return TvmCell object - stateInit
    /// about tvm.buildStateInit read more here (https://github.com/tonlabs/ton-solidity-Compiler/blob/master/API.md#tvmbuildstateinit)
    function _buildPlatformState(TvmCell code) internal view virtual returns (TvmCell) {
        return tvm.buildStateInit({ contr: NftPlatform, varInit: { _id: _id }, code: code });
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
                bytes4(tvm.functionId(ITIP4_6Nft.version)) ^ bytes4(tvm.functionId(ITIP4_6Nft.requestUpgrade)));
    }

    modifier onlyCollection() {
        require(msg.sender == _collection, sender_is_not_collection);
        _;
    }
}
