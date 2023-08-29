interface IEdition {
	function editionInfo()
		external
		view
		responsible
		returns (
			uint128 editionId,
			uint32 editionSupply,
			uint32 editionNumber
		);
}
