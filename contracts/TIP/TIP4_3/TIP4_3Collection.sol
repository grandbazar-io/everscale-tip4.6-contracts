/// We recommend using the compiler version 0.58.1.
/// You can use other versions, but we do not guarantee compatibility of the compiler version.
pragma ton-solidity ^0.58.1;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import "../TIP4_1/TIP4_1Collection.sol";
import "@itgold/everscale-tip/contracts/TIP4_3/interfaces/ITIP4_3Collection.sol";
import "./TIP4_3Nft.sol";
import "@itgold/everscale-tip/contracts/TIP4_3/Index.sol";
import "@itgold/everscale-tip/contracts/TIP4_3/IndexBasis.sol";

/// This contract implement TIP4_1Collection, ITIP4_3Collection (add indexes)
abstract contract TIP4_3Collection is TIP4_1Collection, ITIP4_3Collection {
    /**
     * Errors
     **/
    uint8 constant value_is_empty = 103;

    /// TvmCell object code of Index contract
    TvmCell _codeIndex;

    /// TvmCell object code of IndexBasis contract
    TvmCell _codeIndexBasis;

    /// Values for deploy/destroy
    uint128 _indexDeployValue = 0.15 ton;
    uint128 _indexDestroyValue = 0.1 ton;
    uint128 _deployIndexBasisValue = 0.15 ton;

    /// _codeIndexBasis can't be empty
    /// Balance value must be greater than _indexDeployValue
    function _deployIndexBasis() internal virtual {
        TvmCell empty;
        require(_codeIndexBasis != empty, value_is_empty);
        require(address(this).balance > _deployIndexBasisValue);

        TvmCell code = _buildIndexBasisCode();
        TvmCell state = _buildIndexBasisState(code, address(this));
        address indexBasis = new IndexBasis{ stateInit: state, value: _deployIndexBasisValue }();
    }

    /// @return code - code of IndexBasis contract
    function indexBasisCode() external view responsible override returns (TvmCell code) {
        return { value: 0, flag: 64, bounce: false } (_codeIndexBasis);
    }

    /// @return hash - calculated hash based on the IndexBasis code
    function indexBasisCodeHash() external view responsible override returns (uint256 hash) {
        return { value: 0, flag: 64, bounce: false } tvm.hash(_buildIndexBasisCode());
    }

    /// @return indexBasis - address of IndexBasisCode
    function resolveIndexBasis() external view responsible override returns (address indexBasis) {
        TvmCell code = _buildIndexBasisCode();
        TvmCell state = _buildIndexBasisState(code, address(this));
        uint256 hashState = tvm.hash(state);
        indexBasis = address.makeAddrStd(address(this).wid, hashState);
        return { value: 0, flag: 64, bounce: false } indexBasis;
    }

    /// @notice build IndexBasis code used TvmCell indexBasis code & salt (string stamp)
    /// @return TvmCell indexBasisCode
    /// about salt read more here (https://github.com/tonlabs/ton-solidity-Compiler/blob/master/API.md#tvmcodesalt)
    function _buildIndexBasisCode() internal view virtual returns (TvmCell) {
        string stamp = "nft";
        TvmBuilder salt;
        salt.store(stamp);
        return tvm.setCodeSalt(_codeIndexBasis, salt.toCell());
    }

    /// @notice Generates a StateInit from code and data
    /// @param code TvmCell code - generated via the _buildIndexBasisCode method
    /// @param collection address of token collection contract
    /// @return TvmCell object - stateInit
    /// about tvm.buildStateInit read more here (https://github.com/tonlabs/ton-solidity-Compiler/blob/master/API.md#tvmbuildstateinit)
    function _buildIndexBasisState(TvmCell code, address collection) internal pure virtual returns (TvmCell) {
        return tvm.buildStateInit({ contr: IndexBasis, varInit: { _collection: collection }, code: code });
    }

    /// @return code - code of Index contract
    function indexCode() external view responsible override returns (TvmCell code) {
        return { value: 0, flag: 64, bounce: false } (_codeIndex);
    }

    /// @return hash - calculated hash based on the Index code
    function indexCodeHash() external view responsible override returns (uint256 hash) {
        return { value: 0, flag: 64, bounce: false } tvm.hash(_codeIndex);
    }

    /// Overrides standard method, because Nft contract is changed
    function _buildNftState(TvmCell code, uint256 id) internal pure virtual override returns (TvmCell) {
        return tvm.buildStateInit({ contr: TIP4_3Nft, varInit: { _id: id }, code: code });
    }
}