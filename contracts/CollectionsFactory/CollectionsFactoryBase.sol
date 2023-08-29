pragma ton-solidity ^0.58.1;

pragma AbiHeader expire;
pragma AbiHeader time;
pragma AbiHeader pubkey;

import '../libraries/MsgFlags.sol';
import "@itgold/everscale-tip/contracts/access/OwnableExternal.sol";
import "@itgold/everscale-tip/contracts/TIP6/TIP6.sol";
import "../libraries/BaseErrors.sol";
import "./interfaces/ICollectionsFactory.sol";
import "../abstract/interfaces/IWithdrawalAddress.sol";

abstract contract CollectionsFactoryBase is ICollectionsFactory, IWithdrawalAddress, TIP6, OwnableExternal {
    uint8 constant author_address_can_not_be_zero = 150;
    uint8 constant deployment_is_not_active = 151;

    uint256 _owner;
    TvmCell _codeCollection;
    TvmCell _codeNft;
    TvmCell _codeIndex;
    TvmCell _codeIndexBasis;

    address _withdrawalAddress;

    /// Value that will be left on collection after deployment process
    uint128 _remainOnCollection = 0.5 ever;
    /// Value for processing collection deploy method
    uint128 _minimalGasAmount = 0.4 ever;
    /// Value that this contract takes itself for every deployment
    uint128 _creationPrice;
    uint128 _deployIndexBasisValue = 0.15 ever;
    uint128 _nftMintingFee;
    uint128 _methodsCallsFee = 0.1 ever;
    uint128 _collectionsMinimalGasAmount = 0.2 ever;
    uint128 _indexDeployValue = 0.15 ever;
    uint128 _indexDestroyValue = 0.1 ever;

    uint128 _totalSupply;

    // Can be used to enable/disable coolections deployment
    bool _deploymentIsActive = true;

    /// @param codeCollection code of Collections to deploy
    /// @param codeNft code of NFTs to mint by Collections
    /// @param codeIndex NFTs index code
    /// @param codeIndexBasis Collections index code
    /// @param ownerPubkey owner of this root
    /// @param withdrawalAddress withdrawal address for this root and all collections
    /// @param creationPrice price that this root gets for deployment and lefts on it
    /// @param nftMintingFee price that Collections get for minting and left on them
    constructor(
        TvmCell codeCollection,
        TvmCell codeNft,
        TvmCell codeIndex,
        TvmCell codeIndexBasis,
        uint256 ownerPubkey,
        address withdrawalAddress,
        uint128 creationPrice,
        uint128 nftMintingFee
    ) public OwnableExternal(ownerPubkey) {
        tvm.accept();

        _codeCollection = codeCollection;
        _codeNft = codeNft;
        _codeIndex = codeIndex;
        _codeIndexBasis = codeIndexBasis;

        _withdrawalAddress = withdrawalAddress;

        _creationPrice = creationPrice;
        _nftMintingFee = nftMintingFee;

        _supportedInterfaces[
            bytes4(tvm.functionId(ICollectionsFactory.deployCollection)) ^
                bytes4(tvm.functionId(ICollectionsFactory.onNftCreated)) ^
                bytes4(tvm.functionId(ICollectionsFactory.totalSupply)) ^
                bytes4(tvm.functionId(ICollectionsFactory.getFeesInfo)) ^
                bytes4(tvm.functionId(ICollectionsFactory.deploymentIsActive)) ^
                bytes4(tvm.functionId(ICollectionsFactory.collectionCode)) ^
                bytes4(tvm.functionId(ICollectionsFactory.collectionCodeHash)) ^
                bytes4(tvm.functionId(ICollectionsFactory.collectionAddress))
        ] = true;

        _supportedInterfaces[
            bytes4(tvm.functionId(IWithdrawalAddress.withdrawalAddress))] = true;
    }

    /// @notice Method that Collections can call to emit CollectionsRoot's NftCreated event
    /// @param id Collection ID that is used to proove that collection is the child of the current CollectionsRoot
    /// @param nftId ID of created NFT
    /// @param nft NFT address
    /// @param owner NFT owner address
    /// @param manager NFT manager address
    /// @param creator NFT creator address
    /// @param sendGasTo Change recipient address
    function onNftCreated(
        uint256 id,
        uint256 nftId,
        address nft,
        address owner,
        address manager,
        address creator,
        address sendGasTo
    ) external view virtual override {
        require(msg.sender == _resolveCollection(id), BaseErrors.message_sender_is_not_my_collection);

        tvm.rawReserve(0, 4);
        emit NftCreated(nftId, nft, msg.sender, owner, manager, creator);
        sendGasTo.transfer({ value: 0, flag: MsgFlags.ALL_NOT_RESERVED });
    }

    /// @notice Sets value for creation price
    /// @param value Amount of evers
    function setCreationPrice(uint128 value) external virtual onlyOwner {
        _creationPrice = value;
    }

    /// @notice Sets value for methods calls fee
    /// @param value Amount of evers
    function setMethodCallsFee(uint128 value) external virtual onlyOwner {
        _methodsCallsFee = value;
    }

    /// @notice Sets how many evers should stay on collection after deployment
    /// @param value Amount of evers
    function setRemainOnCollection(uint128 value) external virtual onlyOwner {
        _remainOnCollection = value;
    }

    /// @notice Sets how many evers should be taken for deploy method processing
    /// @param value Amount of evers
    function setMinimalGasAmount(uint128 value) external virtual onlyOwner {
        _minimalGasAmount = value;
    }

    /// @notice Sets minimalGasAmount that will be used in collections contracts
    /// @param value Amount of evers
    function setCollectionsMinimalGasAmount(uint128 value) external virtual onlyOwner {
        _collectionsMinimalGasAmount = value;
    }

    /// @notice Sets address for funds withdrawal. Only current _withdrawalAddress should be able to do this
    /// @param addr New withdrawal address
    function setWithdrawalAddress(address addr) external virtual internalMsg {
        require(msg.sender == _withdrawalAddress, BaseErrors.message_sender_is_not_my_owner);
        tvm.rawReserve(0, 4);

        _withdrawalAddress = addr;
        msg.sender.transfer({ value: 0, flag: MsgFlags.ALL_NOT_RESERVED, bounce: false });
    }

    /// @notice Puts new collections deployments on pause
    function stopCollectionsDeployment() external virtual onlyOwner {
        _deploymentIsActive = false;
    }

    /// @notice Activates new collections deployments
    function startCollectionsDeployment() external virtual onlyOwner {
        _deploymentIsActive = true;
    }

    function withdraw(uint128 value) external view virtual onlyOwner {
        require(address(this).balance - value >= 2 ever, BaseErrors.not_enough_balance_to_withdraw);

        _withdrawalAddress.transfer(value, true);
    }

    function destroy() external virtual onlyOwner {
        require(_totalSupply == 0, BaseErrors.total_supply_is_more_than_zero);
        selfdestruct(_withdrawalAddress);
    }

    /// @notice Returns deployed collections number
    /// @return count Number of deployed collections
    function totalSupply() external view virtual responsible override returns (uint128 count) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } (_totalSupply);
    }

    /// @notice returns current withdrawal address
    /// @return addr Current withdrawal address
    function withdrawalAddress() external view virtual responsible override returns (address addr) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } (_withdrawalAddress);
    }

    /// @notice All fees values getter
    /// @return totalCreationPrice - Sum of all values used in collections deploy method
    /// @return remainOnCollection - Value that will be left on Collection after the entire deploy process is completed
    /// @return creationPrice - Value that will be reserved and left on CollectionsRoot contract
    /// @return deployIndexBasisValue - Value Value for Collection index deploy
    /// @return nftMintingFee - Value that will be reserved and left on Collection contract after mint is completed
    /// @return methodsCallsFee - Value to be sent with some methods calls (like call of SellRoot and AuctionRoot methods duriing collection deployment)
    /// @return minimalGasAmount - Value for processing collection deploy method
    /// @return collectionsMinimalGasAmount - Value for processing mint in collections contracts
    function getFeesInfo()
        external
        view
        virtual
        responsible
        override
        returns (
            uint128 totalCreationPrice,
            uint128 remainOnCollection,
            uint128 creationPrice,
            uint128 deployIndexBasisValue,
            uint128 nftMintingFee,
            uint128 methodsCallsFee,
            uint128 minimalGasAmount,
            uint128 collectionsMinimalGasAmount
        )
    {
        return
            { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } (
                _totalCreationPrice(),
                _remainOnCollection,
                _creationPrice,
                _deployIndexBasisValue,
                _nftMintingFee,
                _methodsCallsFee,
                _minimalGasAmount,
                _collectionsMinimalGasAmount
            );
    }

    /// @notice If isActive is false, then require() must not allow users to deploy collections
    function deploymentIsActive() external view virtual responsible override returns (bool isActive) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } (_deploymentIsActive);
    }

    /// @notice Returns collection code
    function collectionCode() external view virtual responsible override returns (TvmCell code) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } (_buildCollectionCode(address(this)));
    }

    /// @notice Returns collection codeHash
    function collectionCodeHash() external view virtual responsible override returns (uint256 codeHash) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } (tvm.hash(_buildCollectionCode(address(this))));
    }

    /// @notice Returns collection address by its ID
    function collectionAddress(uint256 id) external view virtual responsible override returns (address collection) {
        return { value: 0, flag: MsgFlags.REMAINING_GAS, bounce: false } (_resolveCollection(id));
    }

    /// @notice Returns total collection deployment price. It is used to avoid storing another variable and rewriting it on every fee change
    /// @return Collction total creation price
    function _totalCreationPrice() internal view virtual returns (uint128) {
        return _remainOnCollection + _creationPrice + _deployIndexBasisValue + _methodsCallsFee + _minimalGasAmount;
    }

    /// @notice Resolve collection address using root address & collection ID
    /// @param id Unique collections number
    function _resolveCollection(uint256 id) internal view virtual returns (address collection) {
        TvmCell code = _buildCollectionCode(address(this));
        TvmCell state = _buildCollectionState(code, id);
        uint256 hashState = tvm.hash(state);
        collection = address.makeAddrStd(address(this).wid, hashState);
    }

    /// @notice build collections code using TvmCell collections code & salt (address collectionRoot) ...
    /// ... to create unique Collections address BC collection code & id can be repeated
    /// @param collectionRoot Collection root address
    /// @return Collection code
    /// about salt read more here (https://github.com/tonlabs/TON-Solidity-Compiler/blob/master/API.md#tvmcodesalt)
    function _buildCollectionCode(address collectionRoot) internal view virtual returns (TvmCell) {
        TvmBuilder salt;
        salt.store(collectionRoot);
        return tvm.setCodeSalt(_codeCollection, salt.toCell());
    }

    /// @notice Override this function with your own contract implementation
    /// @notice Generates a StateInit from code and data
    /// @param code Code generated via the _buildCollectionCode method
    /// @param id Unique Collections number
    /// @return TvmCell object - stateInit
    /// about tvm.buildStateInit read more here (https://github.com/tonlabs/TON-Solidity-Compiler/blob/master/API.md#tvmbuildstateinit)
    function _buildCollectionState(TvmCell code, uint256 id) internal pure virtual returns (TvmCell) {
        // return
        // 	tvm.buildStateInit({
        // 		contr: Collection,
        // 		varInit: {_id: id},
        // 		code: code
        // 	});
    }
}
