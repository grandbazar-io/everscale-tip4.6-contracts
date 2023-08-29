pragma ton-solidity ^0.58.1;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "../TIP/TIP4_2/TIP4_2Nft.sol";
import "../TIP/TIP4_3/TIP4_3Nft.sol";
import "../libraries/MsgFlags.sol";
import "./interfaces/INftBurnable.sol";
import "@itgold/everscale-tip/contracts/TIP6/ITIP6.sol";
import "../abstract/interfaces/ITIP4_5.sol";
import "../abstract/interfaces/ITokenBurned.sol";
import "../abstract/interfaces/IRoyalty.sol";
import "../libraries/BaseErrors.sol";

abstract contract NftBase is TIP4_2Nft, TIP4_3Nft, ITIP4_5, INftBurnable, IRoyalty, ITIP6 {
    string _licenseURI;
    string _licenseName;
    mapping(address => uint8) _royalty;
    uint128 _methodsCallsFee = 0.1 ever;

    /// @notice Event emits after NFT transfer
    /// @param to New owner
    event NftTransferred(address to);

    function burn(address sendGasTo) external virtual override onlyManager {
        require(msg.value >= _burnFee(), BaseErrors.not_enough_value);

        _destructIndex(sendGasTo);
        ITokenBurned(_collection).onTokenBurned{
            value: 0,
            flag: MsgFlags.ALL_NOT_RESERVED + MsgFlags.DESTROY_IF_ZERO,
            bounce: false
        }(_id, _owner, _manager, sendGasTo);
    }

    function burnFee() external view responsible override returns (uint128) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } _burnFee();
    }

    function getLicenseURI() external view responsible override returns (string) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } _licenseURI;
    }

    function getLicenseName() external view responsible override returns (string) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } _licenseName;
    }

    function royaltyInfo() external view responsible override returns (mapping(address => uint8) royalty) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } _royalty;
    }

    function _burnFee() internal view virtual returns (uint128) {
        return _indexDestroyValue * 2 + _methodsCallsFee;
    }

    function _beforeChangeOwner(
        address oldOwner,
        address newOwner,
        address sendGasTo,
        mapping(address => CallbackParams) callbacks
    ) internal virtual override(TIP4_1Nft, TIP4_3Nft) {
        TIP4_3Nft._beforeChangeOwner(oldOwner, newOwner, sendGasTo, callbacks);
    }

    function _afterChangeOwner(
        address oldOwner,
        address newOwner,
        address sendGasTo,
        mapping(address => CallbackParams) callbacks
    ) internal virtual override(TIP4_1Nft, TIP4_3Nft) {
        TIP4_3Nft._afterChangeOwner(oldOwner, newOwner, sendGasTo, callbacks);
    }

    function _beforeTransfer(
        address to,
        address sendGasTo,
        mapping(address => CallbackParams) callbacks
    ) internal virtual override(TIP4_1Nft, TIP4_3Nft) {
        TIP4_3Nft._beforeTransfer(to, sendGasTo, callbacks);
    }

    function _afterTransfer(
        address to,
        address sendGasTo,
        mapping(address => CallbackParams) callbacks
    ) internal virtual override(TIP4_1Nft, TIP4_3Nft) {
        TIP4_3Nft._afterTransfer(to, sendGasTo, callbacks);
        emit NftTransferred(to);
    }
}
