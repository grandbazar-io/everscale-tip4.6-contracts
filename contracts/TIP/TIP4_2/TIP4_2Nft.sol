/// We recommend using the compiler version 0.58.1.
/// You can use other versions, but we do not guarantee compatibility of the compiler version.
pragma ton-solidity ^0.58.1;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "../TIP4_1/TIP4_1Nft.sol";
import "@itgold/everscale-tip/contracts/TIP4_2/interfaces/ITIP4_2JSON_Metadata.sol";

/// This contract implement TIP4_1Nft and ITIP4_2JSON_Metadata (add JSON Metadata)
/// ... Read more here (https://github.com/nftalliance/docs/blob/main/src/Standard/TIP-6/1.md)
abstract contract TIP4_2Nft is TIP4_1Nft, ITIP4_2JSON_Metadata {
    /// JSON metadata
    /// In order to fill in this field correctly, see https://github.com/nftalliance/docs/blob/main/src/Standard/TIP-4/2.md
    string _json;

    /// See interfaces/ITIP4_2JSON_Metadata.sol
    function getJson() external view virtual responsible override returns (string json) {
        return { value: 0, flag: 64, bounce: false } (_json);
    }
}
